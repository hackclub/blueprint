module AiReviewer
  module Tools
    class CheckLinkValidity < RubyLLM::Tool
      description "Check if one or more URLs are valid (return HTTP 200). Use this to verify BOM purchase links are real. Does NOT return page content — only whether the link works. Batch up to 10 URLs in a single call."

      params do
        array :urls, description: "Array of URLs to check (max 10)" do
          string description: "URL to check"
        end
      end

      MAX_URLS = 10

      def initialize(project)
        @project = project
        super()
      end

      def execute(urls:)
        Rails.logger.info("[AiReviewer] [project:#{@project.id}] Tool call: CheckLinkValidity(#{urls.length} URLs)")

        urls = urls.first(MAX_URLS)
        results = urls.map { |url| check_url(url) }

        results.join("\n")
      end

      private

      def check_url(url)
        unless url.start_with?("http://", "https://")
          return "#{url} — INVALID (not a URL)"
        end

        conn = Faraday.new do |f|
          f.options.timeout = 10
          f.options.open_timeout = 10
        end

        response = conn.head(url)

        # Some sites block HEAD, fall back to GET
        if response.status == 405 || response.status == 403
          response = conn.get(url)
        end

        # Follow redirects (up to 3)
        3.times do
          break unless response.status.between?(300, 399) && response.headers["location"]
          response = conn.head(response.headers["location"])
        end

        if response.status == 200
          "#{url} — OK"
        else
          "#{url} — HTTP #{response.status}"
        end
      rescue Faraday::TimeoutError
        "#{url} — TIMEOUT"
      rescue StandardError => e
        "#{url} — ERROR (request failed)"
      end
    end
  end
end
