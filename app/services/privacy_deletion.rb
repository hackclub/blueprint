class PrivacyDeletion
  class ManualReviewRequired < StandardError; end
  class ExternalFailure < StandardError; end

  STAFF_FLAGS = %i[admin reviewer fulfiller shopkeeper hcb_integration_enabled].freeze
  OPEN_ORDER_STATES = %i[pending awaiting_verification on_hold].freeze
  BLOB_URL_PATTERN = %r{/(?:rails/active_storage|user-attachments)/blobs/(?:redirect/|proxy/)?[^/\s)"'<>]+/}
  PLACEHOLDER_PROJECT_TITLE = "Deleted project"

  attr_reader :deleted, :retained

  def initialize(subject, dry_run:)
    @emails = Array(subject["emails"]).filter_map { |email| email.to_s.strip.downcase.presence }.uniq
    @slack_id = subject["slack_id"].presence
    @identity_id = subject["identity_id"].presence
    @dry_run = dry_run
    @deleted = {}
    @retained = []
    @users = []
  end

  def call
    ActiveRecord::Base.transaction(requires_new: true) do
      @users = matching_users.lock.to_a
      raise ManualReviewRequired if manual_review_required?

      erase!
      purge_external! unless @dry_run
      AirtableSync.where(record_identifier: @airtable_identifiers).delete_all
      raise ActiveRecord::Rollback if @dry_run
    end
    self
  end

  def found?
    @users.any? || @deleted.any?
  end

  private

  def matching_users
    conditions = []
    if @emails.any?
      conditions << User.where("LOWER(users.email) IN (?)", @emails)
      conditions << User.where("LOWER(users.email) ~ ANY (ARRAY[?])", @emails.map { |email| old_email_pattern(email) })
      conditions << User.where(id: GuildSignup.where("LOWER(guild_signups.email) IN (?)", @emails).select(:user_id))
    end
    conditions << User.where(slack_id: @slack_id) if @slack_id
    conditions << User.where(identity_vault_id: @identity_id) if @identity_id
    conditions.reduce(:or) || User.none
  end

  # DuplicateUserMerger renames merged accounts to local+old@domain, local+old2@domain, ...
  def old_email_pattern(email)
    local, domain = email.split("@", 2)
    "^#{Regexp.escape(local)}\\+old[0-9]*@#{Regexp.escape(domain.to_s)}$"
  end

  def manual_review_required?
    @users.any? { |user| STAFF_FLAGS.any? { |flag| user.public_send(flag) } } ||
      GuildSignup.organizer.where(user_id: @users.map(&:id)).joins(:guild).merge(Guild.where.not(status: :closed)).exists?
  end

  def erase!
    user_ids = @users.map(&:id)
    project_ids = Project.where(user_id: user_ids).ids
    kept_project_ids = reviewed_funded_or_shipped(project_ids)
    entries = JournalEntry.where(user_id: user_ids).or(JournalEntry.where(project_id: project_ids))
    entry_ids = entries.ids
    @guild_signup_ids = GuildSignup.where(user_id: user_ids).ids
    @gorse_item_ids = project_ids.map { |id| GorseService.project_item_id(id) } + entry_ids.map { |id| GorseService.entry_item_id(id) }
    @airtable_identifiers = (project_ids - kept_project_ids).map { |id| "Project##{id}" } + @guild_signup_ids.map { |id| "GuildSignup##{id}" }

    erase_uploads(project_ids, entry_ids)
    erase_contributions(user_ids, project_ids)
    erase_journal_entries(entries, project_ids)
    erase_projects(project_ids, kept_project_ids, entry_ids)
    erase_account_records(user_ids, project_ids)
    detach_retained_records(user_ids, project_ids)
  end

  def reviewed_funded_or_shipped(project_ids)
    (
      DesignReview.where(project_id: project_ids).distinct.pluck(:project_id) +
      BuildReview.where(project_id: project_ids).distinct.pluck(:project_id) +
      ProjectGrant.where(project_id: project_ids).distinct.pluck(:project_id) +
      Package.where(trackable_type: "Project", trackable_id: project_ids).distinct.pluck(:trackable_id)
    ).uniq
  end

  def erase_uploads(project_ids, entry_ids)
    attachments = ActiveStorage::Attachment.where(record_type: "Project", record_id: project_ids)
      .or(ActiveStorage::Attachment.where(record_type: "JournalEntry", record_id: entry_ids))
    texts = JournalEntry.where(id: entry_ids).pluck(:content) + Project.where(id: project_ids).pluck(:description)
    blob_ids = attachments.pluck(:blob_id) + embedded_blob_ids(texts)

    variant_ids = ActiveStorage::VariantRecord.where(blob_id: blob_ids).ids
    blob_ids += ActiveStorage::Attachment.where(record_type: "ActiveStorage::VariantRecord", record_id: variant_ids)
      .or(ActiveStorage::Attachment.where(record_type: "ActiveStorage::Blob", record_id: blob_ids))
      .pluck(:blob_id)
    blob_ids.uniq!
    @blobs = ActiveStorage::Blob.where(id: blob_ids).to_a

    tally :active_storage_attachments, ActiveStorage::Attachment.where(blob_id: blob_ids).delete_all
    tally :active_storage_variant_records, ActiveStorage::VariantRecord.where(id: variant_ids).delete_all
    tally :active_storage_blobs, ActiveStorage::Blob.where(id: blob_ids).delete_all
  end

  def embedded_blob_ids(texts)
    texts.compact.flat_map { |text| text.scan(BLOB_URL_PATTERN) }.uniq
      .filter_map { |url| Marksmith::Renderer::LinkRenderer.find_blob_from_url(url)&.id }
  end

  def erase_contributions(user_ids, project_ids)
    kudos = Kudo.where(user_id: user_ids).or(Kudo.where(project_id: project_ids))
    kudos_project_ids = kudos.where.not(project_id: project_ids).distinct.pluck(:project_id)
    tally :kudos, kudos.delete_all
    Project.where(id: kudos_project_ids)
      .update_all("kudos_count = (SELECT COUNT(*) FROM kudos WHERE kudos.project_id = projects.id)")

    tally :follows, Follow.where(user_id: user_ids).or(Follow.where(project_id: project_ids)).delete_all

    user_ids.each do |user_id|
      viewed = ProjectUserView.where(user_id: user_id).where.not(project_id: project_ids).select(:project_id)
      Project.where(id: viewed).update_all("views_count = GREATEST(views_count - 1, 0)")
      JournalEntry.where("? = ANY(views)", user_id).update_all([ "views = array_remove(views, ?)", user_id ])
    end
    tally :project_user_views, ProjectUserView.where(user_id: user_ids).or(ProjectUserView.where(project_id: project_ids)).delete_all
  end

  def erase_journal_entries(entries, project_ids)
    other_project_ids = entries.where.not(project_id: project_ids).distinct.pluck(:project_id)
    tally :journal_entries, entries.delete_all
    Project.where(id: other_project_ids)
      .update_all("journal_entries_count = (SELECT COUNT(*) FROM journal_entries WHERE journal_entries.project_id = projects.id)")
  end

  def erase_projects(project_ids, kept_project_ids, entry_ids)
    tally :timeline_items, TimelineItem.where(project_id: project_ids).delete_all
    tally :ai_reviews, AiReview.where(project_id: project_ids).delete_all
    tally :disco_recommendations, Disco::Recommendation.where(item_type: "Project", item_id: project_ids)
      .or(Disco::Recommendation.where(item_type: "JournalEntry", item_id: entry_ids))
      .delete_all
    tally :projects, Project.where(id: project_ids - kept_project_ids).delete_all

    retain "projects",
      Project.where(id: kept_project_ids).update_all(
        title: PLACEHOLDER_PROJECT_TITLE, description: nil, demo_link: nil, readme_link: nil, repo_link: nil,
        hackatime_project_keys: [], is_deleted: true, unlisted: true, skip_gh_sync: true, updated_at: Time.current
      ),
      "reviewed, funded or shipped projects are kept as anonymous placeholders because reviews, grants and packages reference them; title, description, links and files are wiped"
  end

  def erase_account_records(user_ids, project_ids)
    expiry_ids = PrivilegedSessionExpiry.where(user_id: user_ids).ids
    emails = (@emails + @users.map { |user| user.email.downcase }).uniq
    allowed_email_ids = AllowedEmail.where("LOWER(email) IN (?)", emails).ids

    tally :guild_signups, GuildSignup.where(id: @guild_signup_ids).delete_all
    tally :task_lists, TaskList.where(user_id: user_ids).delete_all
    tally :privileged_session_expiries, PrivilegedSessionExpiry.where(id: expiry_ids).delete_all
    tally :disco_recommendations, Disco::Recommendation.where(subject_type: "User", subject_id: user_ids).delete_all

    visits = Ahoy::Visit.where(user_id: user_ids)
    tally :ahoy_events, Ahoy::Event.where(user_id: user_ids).or(Ahoy::Event.where(visit_id: visits.select(:id))).delete_all
    tally :ahoy_visits, visits.delete_all

    tally :one_time_passwords, OneTimePassword.where("LOWER(email) IN (?)", emails).delete_all
    tally :email_tracks, EmailTrack.where("LOWER(email) IN (?)", emails).delete_all
    tally :allowed_emails, AllowedEmail.where(id: allowed_email_ids).delete_all

    tally :versions, PaperTrail::Version.where(item_type: "User", item_id: user_ids)
      .or(PaperTrail::Version.where(item_type: "Project", item_id: project_ids))
      .or(PaperTrail::Version.where(item_type: "PrivilegedSessionExpiry", item_id: expiry_ids))
      .or(PaperTrail::Version.where(item_type: "AllowedEmail", item_id: allowed_email_ids))
      .delete_all
    PaperTrail::Version.where(whodunnit: user_ids.map(&:to_s)).update_all(whodunnit: nil)

    tally :flipper_gates, Flipper::Adapters::ActiveRecord::Gate.where(key: "actors", value: user_ids.map { |id| "User;#{id}" }).delete_all
    tally :airtable_syncs, AirtableSync.where(record_identifier: @airtable_identifiers).count
  end

  def detach_retained_records(user_ids, project_ids)
    now = Time.current

    Project.where(design_review_claimed_by_id: user_ids).update_all(design_review_claimed_by_id: nil, design_review_claimed_at: nil)
    Project.where(build_review_claimed_by_id: user_ids).update_all(build_review_claimed_by_id: nil, build_review_claimed_at: nil)

    orders = ShopOrder.where(user_id: user_ids)
    orders.where(state: OPEN_ORDER_STATES).update_all(
      state: ShopOrder.states[:rejected], rejected_at: now, rejected_by_id: nil, rejection_reason: "Account deleted", updated_at: now
    )
    retain "shop orders",
      orders.update_all(frozen_address: nil, phone_number: nil, tracking_number: nil, updated_at: now),
      "kept for accounting and fulfilment; detached from the account, address, phone and tracking number wiped, open orders rejected"

    packages = Package.where(trackable_type: "User", trackable_id: user_ids)
      .or(Package.where(trackable_type: "Project", trackable_id: project_ids))
      .or(Package.where(trackable_type: "ShopOrder", trackable_id: orders.select(:id)))
    retain "packages",
      packages.update_all(
        recipient_name: nil, recipient_email: nil, address_line_1: nil, address_line_2: nil, city: nil,
        state: nil, postal_code: nil, country: nil, tracking_number: nil, updated_at: now
      ),
      "shipping records kept for postage cost accounting; recipient name, email, address and tracking number wiped"

    retain "design reviews", DesignReview.where(project_id: project_ids).or(DesignReview.where(reviewer_id: user_ids)).count,
      "reviews back funding decisions and reviewer stats for other people; they now point at an anonymous placeholder"
    retain "build reviews", BuildReview.where(project_id: project_ids).or(BuildReview.where(reviewer_id: user_ids)).count,
      "reviews back ticket awards and reviewer stats for other people; they now point at an anonymous placeholder"
    retain "project grants", ProjectGrant.where(project_id: project_ids).count,
      "record of grant money issued, kept for accounting; attached to an anonymous placeholder project"
    retain "manual ticket adjustments", ManualTicketAdjustment.where(user_id: user_ids).count,
      "ticket ledger entries kept for accounting; attached to an anonymous placeholder account"

    @users.each do |user|
      user.update_columns(
        email: "deleted-#{user.id}@deleted.invalid", username: nil, avatar: nil, slack_id: nil, timezone_raw: nil,
        github_username: nil, github_installation_id: nil, identity_vault_id: nil, identity_vault_access_token: nil,
        identity_vault_refresh_token: nil, identity_vault_token_expires_at: nil, birthday: nil, idv_country: nil,
        internal_notes: nil, last_active: nil, last_impersonated_at: nil, last_impersonation_ended_at: nil, updated_at: now
      )
    end
    retain "users", @users.size,
      "account row kept as an anonymous placeholder because orders, reviews, grants and ticket adjustments reference it; every personal field is wiped"
  end

  def purge_external!
    @blobs.each(&:delete)
    @users.each { |user| GorseService.delete_user(user) }
    @gorse_item_ids.each { |item_id| GorseService.delete_item_by_id(item_id) }
    @guild_signup_ids.each { |id| AirtableSync.delete_record!(GuildSignup, id) }
  rescue StandardError
    raise ExternalFailure
  end

  def tally(type, rows)
    @deleted[type.to_s] = @deleted.fetch(type.to_s, 0) + rows if rows.positive?
  end

  def retain(type, rows, reason)
    @retained << { type: type, count: rows, reason: reason } if rows.positive?
  end
end
