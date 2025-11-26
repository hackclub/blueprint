class GorseSyncJob < ApplicationJob
  queue_as :background

  def perform
    sync_users
    sync_items
    sync_feedback
  end

  private

  def sync_users
    csv_data = generate_users_csv
    upload_to_gorse("users", csv_data)
  end

  def sync_items
    csv_data = generate_items_csv
    upload_to_gorse("items", csv_data)
  end

  def sync_feedback
    csv_data = generate_feedback_csv
    upload_to_gorse("feedback", csv_data)
  end

  def generate_users_csv
    CSV.generate do |csv|
      csv << [ "UserId", "Labels" ]
      User.find_each do |user|
        csv << [ user.id, "" ]
      end
    end
  end

  def generate_items_csv
    CSV.generate do |csv|
      csv << [ "ItemId", "IsHidden", "Categories", "Timestamp", "Labels", "Comment" ]

      projects_with_journal_updates = Project
        .left_joins(:journal_entries)
        .select("projects.*, MAX(journal_entries.updated_at) as latest_journal_update")
        .group("projects.id")

      projects_with_journal_updates.find_each do |project|
        last_updated = [ project.updated_at, project.latest_journal_update ].compact.max

        csv << [
          GorseService.project_item_id(project),
          project.is_deleted || false,
          "project",
          last_updated.iso8601,
          project.tier || "",
          ""
        ]
      end

      JournalEntry.includes(:project).find_each do |entry|
        csv << [
          GorseService.entry_item_id(entry),
          entry.project.is_deleted || false,
          "entry",
          entry.updated_at.iso8601,
          entry.project&.tier || "",
          ""
        ]
      end
    end
  end

  def generate_feedback_csv
    CSV.generate do |csv|
      csv << [ "FeedbackType", "UserId", "ItemId", "Timestamp" ]

      Ahoy::Event.where(name: "project_view").find_each do |event|
        user_id = event.properties["user_id"]
        project_id = event.properties["project_id"]
        next if user_id.blank? || project_id.blank?

        csv << [
          "view",
          user_id,
          GorseService.project_item_id(project_id),
          event.time.iso8601
        ]
      end

      Follow.find_each do |follow|
        csv << [
          "follow",
          follow.user_id,
          GorseService.project_item_id(follow.project_id),
          follow.created_at.iso8601
        ]
      end
    end
  end

  def upload_to_gorse(type, csv_data)
    base_url = ENV.fetch("GORSE_API_URL", "https://gorse.blueprint.a.selfhosted.hackclub.com")
    url = "#{base_url}/api/bulk/#{type}"
    admin_key = ENV.fetch("GORSE_ADMIN_API_KEY", "")

    io = StringIO.new(csv_data)

    conn = Faraday.new do |f|
      f.request :multipart
      f.adapter Faraday.default_adapter
    end

    response = conn.post(url) do |req|
      req.headers["X-API-KEY"] = admin_key
      req.body = { file: Faraday::UploadIO.new(io, "text/csv", "#{type}.csv") }
    end

    unless response.success?
      raise "Failed to sync #{type} to Gorse: #{response.status} - #{response.body}"
    end

    Rails.logger.info "Successfully synced #{type} to Gorse"
  end
end
