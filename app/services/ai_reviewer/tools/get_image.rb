require "vips"

module AiReviewer
  module Tools
    class GetImage < RubyLLM::Tool
      include AiReviewer::GithubClient

      description "Download and return images from URLs for visual inspection. Use this to examine screenshots, renders, diagrams, or photos referenced in the project. Pass up to 5 URLs at once for batch processing."

      params do
        array :urls, description: "Array of image URLs to download and analyze (max 5)" do
          string description: "Image URL"
        end
      end

      MAX_IMAGES = 5
      MAX_DOWNLOAD_SIZE = 5_242_880 # 5MB download limit
      MAX_SIZE_BYTES = 524_288 # 512KB output limit
      MAX_DIMENSION = 500

      def initialize(project, known_paths: Set.new, seen_resources: nil)
        @project = project
        @known_paths = known_paths
        @seen_resources = seen_resources
        super()
      end

      def execute(urls:)
        Rails.logger.info("[AiReviewer] [project:#{@project.id}] Tool call: GetImage(#{urls.length} URLs)")

        urls = urls.first(MAX_IMAGES)
        results = urls.map { |url| process_image(url) }

        tempfiles = []
        descriptions = []

        results.each do |result|
          if result[:error]
            descriptions << result[:error]
          else
            tempfiles << result[:tempfile]
            descriptions << result[:description]
          end
        end

        if tempfiles.empty?
          error_msg = "All images failed to load:\n#{descriptions.join("\n")}"
          Rails.logger.warn("[AiReviewer] [project:#{@project.id}] GetImage: #{error_msg}")
          return error_msg
        end

        description_text = descriptions.join("\n")
        attachments = tempfiles.map(&:path)

        Rails.logger.info("[AiReviewer] [project:#{@project.id}] GetImage: returning #{tempfiles.length} images")
        content = RubyLLM::Content.new(description_text, attachments)
        # Keep tempfile references alive so GC doesn't delete them before RubyLLM reads the paths
        content.instance_variable_set(:@_tempfiles, tempfiles)
        content
      end

      private

      def process_image(url)
        key = "image:#{url}"
        if @seen_resources&.include?(key)
          return { error: "Already fetched #{url} — use the image from the earlier call." }
        end

        resolved = resolve_url(url)
        display_url = url

        # Fetch via GitHub Contents API for repo files, direct HTTP for everything else
        if resolved[:type] == :repo_path
          raw_data = fetch_via_github_api(resolved[:path])
          display_url = resolved[:path]

          # Fall back to blueprint host if GitHub API fails
          if raw_data.nil? && resolved[:fallback_url]
            Rails.logger.info("[AiReviewer] [project:#{@project.id}] GetImage: GitHub API failed, trying blueprint fallback for #{resolved[:path]}")
            display_url = resolved[:fallback_url]
            raw_data = fetch_image_data(resolved[:fallback_url])
          end
        else
          display_url = resolved[:url]
          raw_data = fetch_image_data(resolved[:url])
        end

        return { error: "Failed to fetch #{display_url}: no data returned" } unless raw_data

        if raw_data.bytesize > MAX_DOWNLOAD_SIZE
          return { error: "Failed to fetch #{url}: Response too large (#{raw_data.bytesize} bytes)" }
        end

        image = Vips::Image.new_from_buffer(raw_data, "")

        if image.width > MAX_DIMENSION || image.height > MAX_DIMENSION
          image = image.thumbnail_image(MAX_DIMENSION, height: MAX_DIMENSION, size: :down)
        end

        data = image.jpegsave_buffer(Q: 40)

        if data.bytesize > MAX_SIZE_BYTES
          data = image.jpegsave_buffer(Q: 20)
        end

        tempfile = Tempfile.new(["ai_reviewer_image", ".jpg"])
        tempfile.binmode
        tempfile.write(data)
        tempfile.flush

        Rails.logger.info("[AiReviewer] [project:#{@project.id}] GetImage: processed #{url} (#{image.width}x#{image.height}, #{data.bytesize} bytes)")

        @seen_resources&.add(key)
        { tempfile: tempfile, description: "Image from #{url} (#{image.width}x#{image.height}, #{data.bytesize} bytes)" }
      rescue StandardError => e
        Rails.logger.error("[AiReviewer] [project:#{@project.id}] GetImage error for #{url}: #{e.message}")
        { error: "Failed to fetch image from #{url}." }
      end

      # Returns { type: :repo_path, path: "...", fallback_url: "..." } for repo files
      # or { type: :url, url: "..." } for external URLs
      def resolve_url(url)
        parsed = @project.parse_repo
        has_repo = parsed && parsed[:org].present? && parsed[:repo_name].present?

        # Absolute URLs — check if it's a raw.githubusercontent.com URL pointing to the same repo
        if url.start_with?("http://", "https://")
          if has_repo
            raw_prefix = "https://raw.githubusercontent.com/#{parsed[:org]}/#{parsed[:repo_name]}/"
            if url.start_with?(raw_prefix)
              # Extract repo-relative path (skip the branch/ref segment)
              remainder = url.delete_prefix(raw_prefix)
              repo_path = URI.decode_www_form_component(remainder.sub(%r{^[^/]+/}, ""))
              return { type: :repo_path, path: repo_path }
            end
          end
          return { type: :url, url: url }
        end

        # Site-relative paths (e.g. /user-attachments/blobs/...)
        if url.start_with?("/")
          repo_path = url.sub(%r{^/}, "")

          if has_repo && @known_paths.include?(repo_path)
            return { type: :repo_path, path: repo_path, fallback_url: "https://blueprint.hackclub.com#{url}" }
          end

          return { type: :url, url: "https://blueprint.hackclub.com#{url}" }
        end

        # Bare relative path (e.g. images/photo.jpg)
        if has_repo && @known_paths.include?(url)
          return { type: :repo_path, path: url }
        end

        # Not in tree, try GitHub API anyway with blueprint fallback
        if has_repo
          return { type: :repo_path, path: url, fallback_url: "https://blueprint.hackclub.com/#{url}" }
        end

        { type: :url, url: url }
      end

      # Fetch image binary data via the GitHub Contents API (through gh-proxy)
      def fetch_via_github_api(repo_path)
        parsed = @project.parse_repo
        return nil unless parsed && parsed[:org].present? && parsed[:repo_name].present?

        encoded_path = repo_path.split("/").map { |segment| ERB::Util.url_encode(segment) }.join("/")
        api_path = "/repos/#{parsed[:org]}/#{parsed[:repo_name]}/contents/#{encoded_path}"
        response = github_fetch(api_path)
        return nil unless response.status == 200

        data = JSON.parse(response.body)
        return nil unless data["encoding"] == "base64" && data["content"].present?

        Base64.decode64(data["content"])
      rescue StandardError => e
        Rails.logger.warn("[AiReviewer] [project:#{@project.id}] GetImage GitHub API failed for #{repo_path}: #{e.message}")
        nil
      end

      # Fetch image binary data via direct HTTP (for external URLs)
      def fetch_image_data(url)
        conn = Faraday.new do |f|
          f.options.timeout = 15
          f.options.open_timeout = 15
          f.headers["User-Agent"] = "BlueprintAiReviewer/1.0"
        end

        response = conn.get(url)
        3.times do
          break unless response.status.between?(300, 399) && response.headers["location"]
          response = conn.get(response.headers["location"])
        end

        return nil unless response.status == 200

        response.body
      rescue StandardError => e
        Rails.logger.warn("[AiReviewer] [project:#{@project.id}] GetImage fetch failed for #{url}: #{e.message}")
        nil
      end
    end
  end
end
