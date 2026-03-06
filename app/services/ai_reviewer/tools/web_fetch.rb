module AiReviewer
  module Tools
    class WebFetch < RubyLLM::Tool
      description "Fetch and extract text content from URLs. Returns the main text content of web pages, stripping HTML. Useful for reading documentation, datasheets, or referenced pages. Pass multiple URLs to batch fetches in one call."

      params do
        array :urls, description: "Array of URLs to fetch content from (max 3 per call). Each URL counts toward the fetch limit." do
          string description: "URL to fetch"
        end
      end

      MAX_CONTENT_LENGTH = 20_000
      MAX_REDIRECTS = 3

      def initialize(project, call_counter: nil)
        @project = project
        @call_counter = call_counter
        super()
      end

      def execute(urls:)
        urls = Array(urls).first(3)

        outputs = urls.map do |url|
          if @call_counter && @call_counter[:count] >= @call_counter[:limit]
            next "**#{url}**\nFetch limit reached (#{@call_counter[:limit]}). Wrap up and summarize what you've found so far."
          end
          @call_counter[:count] += 1 if @call_counter

          Rails.logger.info("[AiReviewer] [project:#{@project.id}] Tool call: WebFetch(#{url.truncate(100)})")
          fetch_one(url)
        end

        outputs.join("\n\n---\n\n")
      end

      private

      def fetch_one(url)
        unless url.start_with?("http://", "https://")
          return "Error: URL must start with http:// or https://"
        end

        response = fetch_with_redirects(url)
        content_type = response.headers["content-type"].to_s

        if content_type.include?("text/html")
          text = extract_html_content(response.body)
        elsif content_type.include?("text/plain") || content_type.include?("application/json")
          text = response.body.to_s
        else
          return "Unsupported content type: #{content_type}"
        end

        result = "# Content from #{url}\n\n#{text}"

        if result.length > MAX_CONTENT_LENGTH
          result = result.truncate(MAX_CONTENT_LENGTH, omission: "\n\n[Content truncated — exceeded #{MAX_CONTENT_LENGTH} characters]")
        end

        result
      rescue StandardError => e
        Rails.logger.error("[AiReviewer] [project:#{@project.id}] WebFetch error for #{url.truncate(80)}: #{e.message}")
        "Error fetching #{url}. Try a different URL."
      end

      def fetch_with_redirects(url)
        redirects = 0

        loop do
          conn = Faraday.new do |f|
            f.options.timeout = 15
            f.options.open_timeout = 15
          end

          response = conn.get(url)

          if response.status.between?(300, 399) && response.headers["location"]
            redirects += 1
            raise "Too many redirects (max #{MAX_REDIRECTS})" if redirects > MAX_REDIRECTS

            url = response.headers["location"]
          else
            return response
          end
        end
      end

      def extract_html_content(html)
        doc = Nokogiri::HTML(html)

        doc.css("script, style, nav, header, footer, aside").each(&:remove)

        main_content = doc.at_css("article") || doc.at_css("main") || doc.at_css("[role='main']")
        element = main_content || doc.at_css("body")

        return "" unless element

        text = element.text
        text = text.gsub(/\n{3,}/, "\n\n").strip
        text
      end
    end
  end
end
