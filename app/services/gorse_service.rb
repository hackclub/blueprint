class GorseService
  PROJECT_PREFIX = "proj-"
  ENTRY_PREFIX = "ent-"

  class << self
    def project_item_id(project_or_id)
      id = project_or_id.is_a?(Project) ? project_or_id.id : project_or_id
      "#{PROJECT_PREFIX}#{id}"
    end

    def entry_item_id(entry_or_id)
      id = entry_or_id.is_a?(JournalEntry) ? entry_or_id.id : entry_or_id
      "#{ENTRY_PREFIX}#{id}"
    end

    def parse_item_id(str)
      str = str.to_s
      if str.start_with?(PROJECT_PREFIX)
        [ :project, str.delete_prefix(PROJECT_PREFIX).to_i ]
      elsif str.start_with?(ENTRY_PREFIX)
        [ :entry, str.delete_prefix(ENTRY_PREFIX).to_i ]
      else
        [ :legacy_project, str.to_i ]
      end
    end

    def sync_user(user)
      return if ENV["SKIP_GORSE"] == "true"
      response = with_retry do
        connection.post("/api/user") do |req|
          req.headers["X-API-KEY"] = api_key
          req.headers["Content-Type"] = "application/json"
          req.body = {
            UserId: user.id.to_s,
            Labels: [],
            Comment: ""
          }.to_json
        end
      end

      handle_response(response, "sync user #{user.id}")
    end

    def delete_user(user)
      return if ENV["SKIP_GORSE"] == "true"
      response = with_retry do
        connection.delete("/api/user/#{CGI.escape(user.id.to_s)}") do |req|
          req.headers["X-API-KEY"] = api_key
        end
      end

      handle_response(response, "delete user #{user.id}")
    end

    def sync_item(item)
      return if ENV["SKIP_GORSE"] == "true"
      case item
      when Project
        sync_project_item(item)
      when JournalEntry
        sync_entry_item(item)
      else
        raise ArgumentError, "Item must be a Project or JournalEntry, got #{item.class}"
      end
    end

    def delete_item(item)
      return if ENV["SKIP_GORSE"] == "true"
      case item
      when Project
        delete_project_item(item)
      when JournalEntry
        delete_entry_item(item)
      else
        raise ArgumentError, "Item must be a Project or JournalEntry, got #{item.class}"
      end
    end

    def delete_item_by_id(item_id)
      return if ENV["SKIP_GORSE"] == "true"
      response = with_retry do
        connection.delete("/api/item/#{CGI.escape(item_id.to_s)}") do |req|
          req.headers["X-API-KEY"] = api_key
        end
      end

      handle_response(response, "delete item #{item_id}")
    end

    def sync_feedback(feedback_type, user_id, item, timestamp)
      return if ENV["SKIP_GORSE"] == "true"
      events = []

      prefixed_id = case item
      when Project
                      project_item_id(item)
      when JournalEntry
                      entry_item_id(item)
      when String
                      if item =~ /\A\d+\z/
                        project_item_id(item)
                      else
                        item
                      end
      else
                      project_item_id(item.to_s)
      end

      events << {
        FeedbackType: feedback_type,
        UserId: user_id.to_s,
        ItemId: prefixed_id,
        Timestamp: timestamp.iso8601
      }

      response = with_retry do
        connection.post("/api/feedback") do |req|
          req.headers["X-API-KEY"] = api_key
          req.headers["Content-Type"] = "application/json"
          req.body = events.to_json
        end
      end

      handle_response(response, "sync feedback #{feedback_type} user=#{user_id} item=#{prefixed_id}")
    end

    def delete_feedback(feedback_type, user_id, item_id)
      return if ENV["SKIP_GORSE"] == "true"
      response = with_retry do
        connection.delete("/api/feedback/#{CGI.escape(feedback_type.to_s)}/#{CGI.escape(user_id.to_s)}/#{CGI.escape(item_id.to_s)}") do |req|
          req.headers["X-API-KEY"] = api_key
        end
      end

      handle_response(response, "delete feedback #{feedback_type} user=#{user_id} item=#{item_id}")
    end

    def get_user_recommendation(user_id, page = 1, per_page = 21, type: :project)
      return [] if ENV["SKIP_GORSE"] == "true"
      offset = (page - 1) * per_page

      response = with_retry do
        category = type == :entry ? "entry" : "project"
        connection.get("/api/recommend/#{CGI.escape(user_id.to_s)}/#{category}") do |req|
          req.headers["X-API-KEY"] = api_key
          req.params["n"] = per_page * 3
          req.params["offset"] = offset
        end
      end

      item_ids = handle_response(response, "get recommendations for user #{user_id}")

      prefix = type == :entry ? ENTRY_PREFIX : PROJECT_PREFIX
      filtered = item_ids.select { |id| id.to_s.start_with?(prefix) }
      ids = filtered.map { |id| parse_item_id(id)[1] }

      ids.first(per_page)
    end

    def get_popular_items(page = 1, per_page = 21, type: :project)
      return [] if ENV["SKIP_GORSE"] == "true"
      offset = (page - 1) * per_page
      category = type == :entry ? "entry" : "project"

      response = with_retry do
        connection.get("/api/popular/#{category}") do |req|
          req.headers["X-API-KEY"] = api_key
          req.params["n"] = per_page
          req.params["offset"] = offset
        end
      end

      items = handle_response(response, "get popular #{category} items")

      prefix = type == :entry ? ENTRY_PREFIX : PROJECT_PREFIX
      items.map { |item| parse_item_id(item["Id"])[1] }
    end

    private

    def sync_project_item(project)
      last_updated = project.updated_at
      if project.journal_entries.loaded?
        latest_journal_update = project.journal_entries.maximum(&:updated_at)
        last_updated = [ last_updated, latest_journal_update ].compact.max
      elsif project.respond_to?(:latest_journal_update) && project.latest_journal_update
        last_updated = [ last_updated, project.latest_journal_update ].compact.max
      end

      item_id = project_item_id(project)

      response = with_retry do
        connection.post("/api/item") do |req|
          req.headers["X-API-KEY"] = api_key
          req.headers["Content-Type"] = "application/json"
          req.body = {
            ItemId: item_id,
            IsHidden: project.is_deleted || false,
            Categories: [ "project" ],
            Timestamp: last_updated.iso8601,
            Labels: [ project.tier ].compact,
            Comment: ""
          }.to_json
        end
      end

      handle_response(response, "sync project #{item_id}")
    end

    def sync_entry_item(entry)
      item_id = entry_item_id(entry)

      response = with_retry do
        connection.post("/api/item") do |req|
          req.headers["X-API-KEY"] = api_key
          req.headers["Content-Type"] = "application/json"
          req.body = {
            ItemId: item_id,
            IsHidden: entry.project.is_deleted || false,
            Categories: [ "entry" ],
            Timestamp: entry.updated_at.iso8601,
            Labels: [ entry.project&.tier ].compact,
            Comment: ""
          }.to_json
        end
      end

      handle_response(response, "sync entry #{item_id}")
    end

    def delete_project_item(project)
      item_id = project_item_id(project)

      response = with_retry do
        connection.delete("/api/item/#{CGI.escape(item_id)}") do |req|
          req.headers["X-API-KEY"] = api_key
        end
      end

      handle_response(response, "delete project #{item_id}")
    end

    def delete_entry_item(entry)
      item_id = entry_item_id(entry)

      response = with_retry do
        connection.delete("/api/item/#{CGI.escape(item_id)}") do |req|
          req.headers["X-API-KEY"] = api_key
        end
      end

      handle_response(response, "delete entry #{item_id}")
    end

    def base_url
      ENV.fetch("GORSE_API_URL", "https://gorse.blueprint.a.selfhosted.hackclub.com")
    end

    def api_key
      ENV.fetch("GORSE_ADMIN_API_KEY", "")
    end

    def connection
      @connection ||= Faraday.new(url: base_url) do |f|
        f.adapter Faraday.default_adapter
      end
    end

    def handle_response(response, action)
      unless response.success?
        # sentry capture
        Rails.logger.error("Gorse request failed to #{action}: #{response.status} - #{response.body}")
        Sentry.capture_message("Gorse request failed to #{action}: #{response.status} - #{response.body}")
        return {}
      end

      JSON.parse(response.body)
    end

    def with_retry(max = 3)
      retries = 0
      begin
        yield
      rescue Faraday::ConnectionFailed, Faraday::TimeoutError, SocketError => e
        retries += 1
        if retries <= max
          Rails.logger.warn "Gorse request failed (try #{retries}/#{max + 1}): #{e.message}"
          sleep(0.5 * retries)
          retry
        else
          Rails.logger.error "Gorse request failed after retry: #{e.message}"
          Sentry.capture_exception(e)
          raise
        end
      end
    end
  end
end
