module AiReviewer
  module Tools
    class WebSearch < RubyLLM::Tool
      description "Search the web for information. Use this to look up component datasheets, specs, compatibility info, documentation, or find reference materials. Pass multiple queries to batch searches in one call."

      params do
        array :queries, description: "Array of search queries (max 5 per call). Each query counts toward the search limit." do
          string description: "Search query"
        end
        integer :num_results, description: "Number of results to return per query (default 5, max 10)"
      end

      attr_reader :search_count

      def initialize(project, call_counter: nil)
        @project = project
        @search_count = 0
        @call_counter = call_counter
        super()
      end

      def execute(queries:, num_results: 5)
        queries = Array(queries).first(5)
        num_results = [[num_results.to_i, 1].max, 10].min

        api_key = ENV.fetch("BRIGHT_DATA_SERP_API_KEY", "")
        zone = ENV.fetch("BRIGHT_DATA_SERP_ZONE", "")
        if api_key.blank? || zone.blank?
          Sentry.capture_message("WebSearch is not configured: missing BRIGHT_DATA_SERP_API_KEY or BRIGHT_DATA_SERP_ZONE", level: :error)
          return "WebSearch is not available."
        end

        outputs = queries.map do |query|
          if @call_counter && @call_counter[:count] >= @call_counter[:limit]
            next "**Search: #{query}**\nSearch limit reached (#{@call_counter[:limit]}). Wrap up and summarize what you've found so far."
          end
          @call_counter[:count] += 1 if @call_counter

          Rails.logger.info("[AiReviewer] [project:#{@project.id}] Tool call: WebSearch(#{query.truncate(100)})")
          search_one(query, num_results, api_key, zone)
        end

        outputs.join("\n\n---\n\n")
      end

      private

      def search_one(query, num_results, api_key, zone)
        search_url = "https://www.google.com/search?q=#{ERB::Util.url_encode(query)}&num=#{num_results}&hl=en&gl=us"

        conn = Faraday.new(url: "https://api.brightdata.com") do |f|
          f.options.timeout = 30
          f.options.open_timeout = 15
          f.request :json
        end

        response = conn.post("/request") do |req|
          req.headers["Content-Type"] = "application/json"
          req.headers["Authorization"] = "Bearer #{api_key}"
          req.body = { zone: zone, url: search_url, format: "raw", data_format: "parsed_light" }
        end

        @search_count += 1
        body = response.body.is_a?(String) ? JSON.parse(response.body) : response.body
        results = body.dig("organic") || []

        if results.empty?
          return "**Search: #{query}**\nNo results found."
        end

        output = results.first(num_results).each_with_index.map do |result, index|
          title = result["title"] || "No title"
          link = result["link"] || ""
          snippet = result["description"] || result["snippet"] || "No description available"

          "#{index + 1}. **#{title}** (#{link})\n   #{snippet}"
        end.join("\n\n")

        "**Search: #{query}**\n\n#{output}".truncate(10_000)
      rescue StandardError => e
        Rails.logger.error("[AiReviewer] [project:#{@project.id}] WebSearch error for '#{query.truncate(50)}': #{e.message}")
        "**Search: #{query}**\nSearch failed for this query. Try rephrasing."
      end
    end
  end
end
