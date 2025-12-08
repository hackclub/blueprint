# frozen_string_literal: true

class DuplicateUserMerger
  attr_reader :report, :dry_run

  def initialize(dry_run: true)
    @dry_run = dry_run
    @report = []
  end

  def run
    duplicate_email_groups.each do |normalized_email, user_ids|
      users = User.where(id: user_ids).order(:created_at, :id).to_a
      process_group(normalized_email, users)
    end

    @report
  end

  def print_report
    conflicts = @report.select { |r| r[:status] == "conflict" }
    dry_runs = @report.select { |r| r[:status] == "dry_run" }
    merged = @report.select { |r| r[:status] == "merged" }

    puts "=" * 80
    puts "DUPLICATE USER MERGE REPORT"
    puts "=" * 80
    puts "Mode: #{@dry_run ? 'DRY RUN (no changes made)' : 'LIVE RUN'}"
    puts "Total duplicate groups: #{@report.size}"
    puts "  - Conflicts (manual review needed): #{conflicts.size}"
    puts "  - #{@dry_run ? 'Would merge' : 'Merged'}: #{dry_runs.size + merged.size}"
    puts "=" * 80
    puts

    if conflicts.any?
      puts "CONFLICTS - MANUAL REVIEW REQUIRED"
      puts "-" * 80
      conflicts.each do |r|
        print_group_report(r)
      end
      puts
    end

    mergeable = @dry_run ? dry_runs : merged
    if mergeable.any?
      puts "#{@dry_run ? 'WILL MERGE' : 'MERGED'}"
      puts "-" * 80
      mergeable.each do |r|
        print_group_report(r)
      end
    end
  end

  private

  def print_group_report(r)
    puts
    puts "Email: #{r[:normalized_email]}"
    puts "Status: #{r[:status].upcase}"
    puts "Users in group: #{r[:user_ids].join(', ')}"

    if r[:status] == "conflict"
      puts "Conflicts:"
      r[:conflicts].each { |c| puts "  - #{c}" }
    else
      puts "Primary user: #{r[:primary_id]} (will keep)"
      puts "Old users: #{r[:other_ids].join(', ')} (will be deactivated)"
      puts
      puts "Changes to primary user:"
      r[:primary_changes].each do |field, change|
        puts "  #{field}: #{change[:from].inspect} -> #{change[:to].inspect}"
      end
      puts
      puts "Email changes for old accounts:"
      r[:email_changes].each do |user_id, new_email|
        puts "  User #{user_id}: -> #{new_email}"
      end
      puts
      puts "Association reassignments:"
      r[:reassignments].each do |table, count|
        puts "  #{table}: #{count} records" if count > 0
      end
    end
    puts "-" * 40
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
    conflicts << "multiple_identity_vault_ids: #{idv_ids.inspect}" if idv_ids.size > 1

    slack_ids = users.filter_map(&:slack_id).uniq
    conflicts << "multiple_slack_ids: #{slack_ids.inspect}" if slack_ids.size > 1

    github_usernames = users.filter_map(&:github_username).uniq
    conflicts << "multiple_github_usernames: #{github_usernames.inspect}" if github_usernames.size > 1

    github_installation_ids = users.filter_map(&:github_installation_id).uniq
    conflicts << "multiple_github_installation_ids: #{github_installation_ids.inspect}" if github_installation_ids.size > 1

    birthdays = users.filter_map(&:birthday).uniq
    conflicts << "multiple_birthdays: #{birthdays.inspect}" if birthdays.size > 1

    referrers = users.filter_map(&:referrer_id).uniq
    conflicts << "multiple_referrer_ids: #{referrers.inspect}" if referrers.size > 1

    if users.map(&:admin).uniq.size > 1
      conflicts << "admin_flag_differs"
    end

    if users.count { |u| u.task_list.present? } > 1
      conflicts << "multiple_task_lists"
    end

    if review_uniqueness_conflict?(users)
      conflicts << "multiple_reviews_same_project"
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

  def compute_merged_attributes(primary, users)
    merged = {}
    changes = {}

    new_email = primary.email.downcase
    if primary.email != new_email
      changes[:email] = { from: primary.email, to: new_email }
    end
    merged[:email] = new_email

    donor_with_idv = users.find { |u| u.identity_vault_id.present? }
    if donor_with_idv
      %i[identity_vault_id identity_vault_access_token ysws_verified idv_country].each do |field|
        new_val = donor_with_idv.send(field)
        if primary.send(field) != new_val
          changes[field] = { from: primary.send(field), to: new_val }
        end
        merged[field] = new_val
      end
    end

    donor_with_bday = users.find { |u| u.birthday.present? }
    if donor_with_bday && primary.birthday != donor_with_bday.birthday
      changes[:birthday] = { from: primary.birthday, to: donor_with_bday.birthday }
      merged[:birthday] = donor_with_bday.birthday
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
      donor = users.find { |u| u.send(field).present? }
      if donor && primary.send(field).nil?
        changes[field] = { from: nil, to: donor.send(field) }
        merged[field] = donor.send(field)
      end
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
    TaskList.where(user_id: other_ids).update_all(user_id: primary.id)
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
    if conflicts.any?
      @report << {
        normalized_email: normalized_email,
        user_ids: users.map(&:id),
        primary_id: primary.id,
        other_ids: others.map(&:id),
        status: "conflict",
        conflicts: conflicts
      }
      return
    end

    merged_attrs, primary_changes = compute_merged_attributes(primary, users)
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

    User.transaction do
      reassign_associations(primary, others)
      primary.update!(merged_attrs)
      deactivate_old_accounts(others_with_new_emails)
    end

    @report << summary.merge(status: "merged")
  end
end
