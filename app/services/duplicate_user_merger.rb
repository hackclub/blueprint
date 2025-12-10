# frozen_string_literal: true

class DuplicateUserMerger
  attr_reader :report, :dry_run, :interactive, :pending_merges

  def initialize(dry_run: true, interactive: false)
    @dry_run = dry_run
    @interactive = interactive
    @report = []
    @pending_merges = []
  end

  def run
    duplicate_email_groups.each do |normalized_email, user_ids|
      users = User.where(id: user_ids).order(:created_at, :id).to_a
      process_group(normalized_email, users)
    end

    if @interactive && @pending_merges.any?
      execute_pending_merges
    end

    @report
  end

  def save_report(filename = nil)
    filename ||= Rails.root.join("tmp", "duplicate_user_merge_#{Time.current.strftime('%Y%m%d_%H%M%S')}.txt")
    File.open(filename, "w") { |f| print_report(output: f) }
    filename
  end

  def print_report(output: $stdout)
    conflicts = @report.select { |r| r[:status] == "conflict" }
    dry_runs = @report.select { |r| r[:status] == "dry_run" }
    merged = @report.select { |r| r[:status] == "merged" }

    output.puts "=" * 80
    output.puts "DUPLICATE USER MERGE REPORT"
    output.puts "=" * 80
    output.puts "Mode: #{@dry_run ? 'DRY RUN (no changes made)' : 'LIVE RUN'}"
    output.puts "Total duplicate groups: #{@report.size}"
    output.puts "  - Conflicts (manual review needed): #{conflicts.size}"
    output.puts "  - #{@dry_run ? 'Would merge' : 'Merged'}: #{dry_runs.size + merged.size}"
    output.puts "=" * 80
    output.puts

    if conflicts.any?
      output.puts "CONFLICTS - MANUAL REVIEW REQUIRED"
      output.puts "-" * 80
      conflicts.each do |r|
        print_group_report(r, output: output)
      end
      output.puts
    end

    mergeable = @dry_run ? dry_runs : merged
    if mergeable.any?
      output.puts "#{@dry_run ? 'WILL MERGE' : 'MERGED'}"
      output.puts "-" * 80
      mergeable.each do |r|
        print_group_report(r, output: output)
      end
    end
  end

  private

  def print_group_report(r, output: $stdout)
    output.puts
    output.puts "Email: #{r[:normalized_email]}"
    output.puts "Status: #{r[:status].upcase}"
    output.puts "Users in group: #{r[:user_ids].join(', ')}"

    if r[:status] == "conflict"
      output.puts "Conflicts:"
      r[:conflicts].each { |c| output.puts "  - #{c}" }
    else
      output.puts "Primary user: #{r[:primary_id]} (will keep)"
      output.puts "Old users: #{r[:other_ids].join(', ')} (will be deactivated)"
      output.puts
      output.puts "Changes to primary user:"
      r[:primary_changes].each do |field, change|
        output.puts "  #{field}: #{change[:from].inspect} -> #{change[:to].inspect}"
      end
      output.puts
      output.puts "Email changes for old accounts:"
      r[:email_changes].each do |user_id, new_email|
        output.puts "  User #{user_id}: -> #{new_email}"
      end
      output.puts
      output.puts "Association reassignments:"
      r[:reassignments].each do |table, count|
        output.puts "  #{table}: #{count} records" if count > 0
      end
    end
    output.puts "-" * 40
  end

  def duplicate_email_groups
    User
      .group("LOWER(email)")
      .having("COUNT(*) > 1")
      .pluck(Arel.sql("LOWER(email)"), Arel.sql("array_agg(id ORDER BY created_at, id)"))
  end

  def choose_primary(users)
    users.min_by { |u| [ u.created_at, u.id ] }
  end

  def detect_conflicts(users)
    conflicts = []

    idv_ids = users.filter_map(&:identity_vault_id).uniq
    conflicts << { field: :identity_vault_id, values: idv_ids, users: users.select { |u| u.identity_vault_id.present? } } if idv_ids.size > 1

    slack_ids = users.filter_map(&:slack_id).uniq
    conflicts << { field: :slack_id, values: slack_ids, users: users.select { |u| u.slack_id.present? } } if slack_ids.size > 1

    github_usernames = users.filter_map(&:github_username).uniq
    conflicts << { field: :github_username, values: github_usernames, users: users.select { |u| u.github_username.present? } } if github_usernames.size > 1

    github_installation_ids = users.filter_map(&:github_installation_id).uniq
    conflicts << { field: :github_installation_id, values: github_installation_ids, users: users.select { |u| u.github_installation_id.present? } } if github_installation_ids.size > 1

    birthdays = users.filter_map(&:birthday).uniq
    conflicts << { field: :birthday, values: birthdays, users: users.select { |u| u.birthday.present? } } if birthdays.size > 1

    if users.any? { |u| u.admin? || u.reviewer? || u.fulfiller? }
      conflicts << { field: :roles, values: nil, users: users.select { |u| u.admin? || u.reviewer? || u.fulfiller? }, unresolvable: true }
    end

    if review_uniqueness_conflict?(users)
      conflicts << { field: :reviews, values: nil, users: users, unresolvable: true }
    end

    conflicts
  end

  def review_uniqueness_conflict?(users)
    user_ids = users.map(&:id)

    design_conflict = DesignReview
      .where(reviewer_id: user_ids, invalidated: false)
      .group(:project_id)
      .having("COUNT(DISTINCT reviewer_id) > 1")
      .exists?

    build_conflict = BuildReview
      .where(reviewer_id: user_ids, invalidated: false)
      .group(:project_id)
      .having("COUNT(DISTINCT reviewer_id) > 1")
      .exists?

    design_conflict || build_conflict
  end

  def compute_merged_attributes(primary, users, resolved_values = {})
    merged = {}
    changes = {}

    new_email = primary.email.downcase
    if primary.email != new_email
      changes[:email] = { from: primary.email, to: new_email }
    end
    merged[:email] = new_email

    if resolved_values[:identity_vault_id]
      donor_with_idv = users.find { |u| u.identity_vault_id == resolved_values[:identity_vault_id] }
    else
      donor_with_idv = users.find { |u| u.identity_vault_id.present? }
    end
    if donor_with_idv
      %i[identity_vault_id identity_vault_access_token ysws_verified idv_country].each do |field|
        new_val = donor_with_idv.send(field)
        if primary.send(field) != new_val
          changes[field] = { from: primary.send(field), to: new_val }
        end
        merged[field] = new_val
      end
    end

    birthday_val = resolved_values[:birthday] || users.find { |u| u.birthday.present? }&.birthday
    if birthday_val && primary.birthday != birthday_val
      changes[:birthday] = { from: primary.birthday, to: birthday_val }
      merged[:birthday] = birthday_val
    end

    donor_with_referrer = users.find { |u| u.referrer_id.present? }
    if donor_with_referrer && primary.referrer_id != donor_with_referrer.referrer_id
      changes[:referrer_id] = { from: primary.referrer_id, to: donor_with_referrer.referrer_id }
      merged[:referrer_id] = donor_with_referrer.referrer_id
    end

    if users.any?(&:is_banned)
      unless primary.is_banned
        changes[:is_banned] = { from: false, to: true }
      end
      merged[:is_banned] = true

      ban_types = users.filter_map(&:ban_type).uniq
      if ban_types.any? && primary.ban_type != ban_types.first
        changes[:ban_type] = { from: primary.ban_type, to: ban_types.first }
        merged[:ban_type] = ban_types.first
      end
    end

    %i[slack_id github_username github_installation_id].each do |field|
      if resolved_values[field]
        new_val = resolved_values[field]
        if primary.send(field) != new_val
          changes[field] = { from: primary.send(field), to: new_val }
        end
        merged[field] = new_val
      else
        donor = users.find { |u| u.send(field).present? }
        if donor && primary.send(field).nil?
          changes[field] = { from: nil, to: donor.send(field) }
          merged[field] = donor.send(field)
        end
      end
    end

    if users.any?(&:free_stickers_claimed)
      unless primary.free_stickers_claimed
        changes[:free_stickers_claimed] = { from: false, to: true }
      end
      merged[:free_stickers_claimed] = true
    end

    %i[avatar username timezone_raw].each do |field|
      if primary.send(field).blank?
        donor = users.find { |u| u.send(field).present? }
        if donor
          changes[field] = { from: primary.send(field), to: donor.send(field) }
          merged[field] = donor.send(field)
        end
      end
    end

    [ merged, changes ]
  end

  def compute_old_emails(normalized_email, others)
    local, domain = normalized_email.split("@", 2)

    others.each_with_index.map do |user, idx|
      suffix = idx == 0 ? "+old" : "+old#{idx + 1}"
      new_email = "#{local}#{suffix}@#{domain}"
      [ user, new_email ]
    end
  end

  def count_reassignments(primary, others)
    other_ids = others.map(&:id)
    return {} if other_ids.empty?

    {
      projects: Project.where(user_id: other_ids).count,
      journal_entries: JournalEntry.where(user_id: other_ids).count,
      follows: Follow.where(user_id: other_ids).count,
      design_reviews: DesignReview.where(reviewer_id: other_ids).count,
      build_reviews: BuildReview.where(reviewer_id: other_ids).count,
      manual_ticket_adjustments: ManualTicketAdjustment.where(user_id: other_ids).count,
      task_lists: TaskList.where(user_id: other_ids).count,
      kudos: Kudo.where(user_id: other_ids).count,
      shop_orders_user: ShopOrder.where(user_id: other_ids).count,
      shop_orders_approved_by: ShopOrder.where(approved_by_id: other_ids).count,
      shop_orders_fufilled_by: ShopOrder.where(fufilled_by_id: other_ids).count,
      shop_orders_rejected_by: ShopOrder.where(rejected_by_id: other_ids).count,
      shop_orders_on_hold_by: ShopOrder.where(on_hold_by_id: other_ids).count,
      ahoy_visits: Ahoy::Visit.where(user_id: other_ids).count,
      ahoy_events: Ahoy::Event.where(user_id: other_ids).count,
      referrals: User.where(referrer_id: other_ids).where.not(id: primary.id).count
    }
  end

  def reassign_associations(primary, others)
    other_ids = others.map(&:id)
    return if other_ids.empty?

    Project.where(user_id: other_ids).update_all(user_id: primary.id)
    JournalEntry.where(user_id: other_ids).update_all(user_id: primary.id)

    Follow.where(user_id: other_ids).find_each do |f|
      existing = Follow.find_by(user_id: primary.id, project_id: f.project_id)
      if existing
        f.destroy
      else
        f.update!(user_id: primary.id)
      end
    end

    DesignReview.where(reviewer_id: other_ids).update_all(reviewer_id: primary.id)
    BuildReview.where(reviewer_id: other_ids).update_all(reviewer_id: primary.id)
    ManualTicketAdjustment.where(user_id: other_ids).update_all(user_id: primary.id)
    TaskList.where(user_id: other_ids).destroy_all
    Kudo.where(user_id: other_ids).update_all(user_id: primary.id)

    ShopOrder.where(user_id: other_ids).update_all(user_id: primary.id)
    ShopOrder.where(approved_by_id: other_ids).update_all(approved_by_id: primary.id)
    ShopOrder.where(fufilled_by_id: other_ids).update_all(fufilled_by_id: primary.id)
    ShopOrder.where(rejected_by_id: other_ids).update_all(rejected_by_id: primary.id)
    ShopOrder.where(on_hold_by_id: other_ids).update_all(on_hold_by_id: primary.id)

    Ahoy::Visit.where(user_id: other_ids).update_all(user_id: primary.id)
    Ahoy::Event.where(user_id: other_ids).update_all(user_id: primary.id)

    User.where(referrer_id: other_ids).where.not(id: primary.id).update_all(referrer_id: primary.id)
  end

  def deactivate_old_accounts(others_with_new_emails)
    others_with_new_emails.each do |user, new_email|
      user.update!(
        email: new_email.downcase,
        identity_vault_id: nil,
        identity_vault_access_token: nil,
        ysws_verified: nil,
        idv_country: nil,
        slack_id: nil,
        github_username: nil,
        github_installation_id: nil
      )
    end
  end

  def process_group(normalized_email, users)
    primary = choose_primary(users)
    others = users - [ primary ]

    conflicts = detect_conflicts(users)
    resolvable_conflicts = conflicts.reject { |c| c[:unresolvable] }
    unresolvable_conflicts = conflicts.select { |c| c[:unresolvable] }

    if unresolvable_conflicts.any?
      @report << {
        normalized_email: normalized_email,
        user_ids: users.map(&:id),
        primary_id: primary.id,
        other_ids: others.map(&:id),
        status: "conflict",
        conflicts: conflicts.map { |c| format_conflict(c) }
      }
      return
    end

    resolved_values = {}
    if resolvable_conflicts.any?
      if @interactive
        resolved_values = resolve_conflicts_interactively(normalized_email, users, resolvable_conflicts)
        return if resolved_values.nil?
      else
        @report << {
          normalized_email: normalized_email,
          user_ids: users.map(&:id),
          primary_id: primary.id,
          other_ids: others.map(&:id),
          status: "conflict",
          conflicts: conflicts.map { |c| format_conflict(c) }
        }
        return
      end
    end

    merged_attrs, primary_changes = compute_merged_attributes(primary, users, resolved_values)
    others_with_new_emails = compute_old_emails(normalized_email, others)
    reassignments = count_reassignments(primary, others)

    summary = {
      normalized_email: normalized_email,
      user_ids: users.map(&:id),
      primary_id: primary.id,
      other_ids: others.map(&:id),
      primary_changes: primary_changes,
      email_changes: others_with_new_emails.to_h { |u, e| [ u.id, e ] },
      reassignments: reassignments
    }

    if @dry_run
      @report << summary.merge(status: "dry_run")
      return
    end

    if @interactive
      @pending_merges << {
        summary: summary,
        primary: primary,
        others: others,
        merged_attrs: merged_attrs,
        others_with_new_emails: others_with_new_emails
      }
      @report << summary.merge(status: "pending")
    else
      User.transaction do
        reassign_associations(primary, others)
        primary.update!(merged_attrs)
        deactivate_old_accounts(others_with_new_emails)
      end
      @report << summary.merge(status: "merged")
    end
  end

  def format_conflict(conflict)
    if conflict[:unresolvable]
      "#{conflict[:field]}: unresolvable (users: #{conflict[:users].map(&:id).join(', ')})"
    else
      "#{conflict[:field]}: #{conflict[:values].inspect}"
    end
  end

  def resolve_conflicts_interactively(normalized_email, users, conflicts)
    puts
    puts "=" * 60
    puts "CONFLICT RESOLUTION: #{normalized_email}"
    puts "=" * 60
    puts "Users in group:"
    users.each do |u|
      puts "  ID #{u.id}: created #{u.created_at.strftime('%Y-%m-%d')}, email: #{u.email}"
    end
    puts

    resolved = {}

    conflicts.each do |conflict|
      field = conflict[:field]
      puts "Conflict: #{field}"
      puts "-" * 40

      conflict[:users].each_with_index do |user, idx|
        value = user.send(field)
        puts "  [#{idx + 1}] User #{user.id}: #{value}"
      end
      puts "  [s] Skip this group entirely"
      puts

      loop do
        print "Choose option (1-#{conflict[:users].size}, or 's' to skip): "
        input = $stdin.gets&.strip&.downcase

        if input == "s"
          puts "Skipping this group..."
          return nil
        end

        choice = input.to_i
        if choice >= 1 && choice <= conflict[:users].size
          chosen_user = conflict[:users][choice - 1]
          resolved[field] = chosen_user.send(field)
          puts "Selected: #{resolved[field]}"
          puts
          break
        else
          puts "Invalid choice. Please try again."
        end
      end
    end

    resolved
  end

  def execute_pending_merges
    return if @pending_merges.empty?

    puts
    puts "=" * 80
    puts "SUMMARY OF PENDING MERGES"
    puts "=" * 80
    puts "Total merges to execute: #{@pending_merges.size}"
    puts

    @pending_merges.each_with_index do |merge, idx|
      summary = merge[:summary]
      puts "#{idx + 1}. #{summary[:normalized_email]}"
      puts "   Primary: User #{summary[:primary_id]}"
      puts "   Will deactivate: #{summary[:other_ids].join(', ')}"
      puts "   Changes: #{summary[:primary_changes].keys.join(', ')}" if summary[:primary_changes].any?
      puts "   Reassignments: #{summary[:reassignments].select { |_, v| v > 0 }.map { |k, v| "#{k}: #{v}" }.join(', ')}"
      puts
    end

    puts "=" * 80
    print "Execute all #{@pending_merges.size} merges? (yes/no): "
    input = $stdin.gets&.strip&.downcase

    if input == "yes"
      puts
      puts "Executing merges..."

      @pending_merges.each do |merge|
        User.transaction do
          reassign_associations(merge[:primary], merge[:others])
          merge[:primary].update!(merge[:merged_attrs])
          deactivate_old_accounts(merge[:others_with_new_emails])
        end

        idx = @report.find_index { |r| r[:normalized_email] == merge[:summary][:normalized_email] && r[:status] == "pending" }
        @report[idx] = merge[:summary].merge(status: "merged") if idx
        puts "  Merged: #{merge[:summary][:normalized_email]}"
      end

      puts
      puts "All merges completed successfully!"
    else
      puts "Aborted. No changes were made."
      @pending_merges.each do |merge|
        idx = @report.find_index { |r| r[:normalized_email] == merge[:summary][:normalized_email] && r[:status] == "pending" }
        @report[idx] = merge[:summary].merge(status: "aborted") if idx
      end
    end
  end
end
