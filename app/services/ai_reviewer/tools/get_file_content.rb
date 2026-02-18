module AiReviewer
  module Tools
    class GetFileContent < RubyLLM::Tool
      include AiReviewer::GithubClient

      description "Get the contents of a file from the GitHub repository. You can read the entire file or specify a line range."

      params do
        string :path, description: "File path relative to repo root (e.g. 'README.md', 'firmware/main.c')"
        integer :start_line, description: "First line to return (1-indexed). Omit to read from the beginning.", required: false
        integer :end_line, description: "Last line to return (1-indexed). Omit to read to the end.", required: false
      end

      def initialize(project)
        @project = project
        super()
      end

      def execute(path:, start_line: nil, end_line: nil)
        range_label = start_line || end_line ? ":#{start_line || 1}-#{end_line || 'end'}" : ""
        Rails.logger.info("[AiReviewer] [project:#{@project.id}] Tool call: GetFileContent(#{path}#{range_label})")

        parsed = @project.parse_repo
        return "No GitHub repo linked." unless parsed && parsed[:org].present? && parsed[:repo_name].present?

        encoded_path = path.split("/").map { |segment| ERB::Util.url_encode(segment) }.join("/")
        api_path = "/repos/#{parsed[:org]}/#{parsed[:repo_name]}/contents/#{encoded_path}"
        response = github_fetch(api_path)
        unless response.status == 200
          Rails.logger.warn("[AiReviewer] [project:#{@project.id}] GetFileContent: #{path} not found (HTTP #{response.status})")
          return "File not found: #{path} (HTTP #{response.status})."
        end

        data = JSON.parse(response.body)

        if data["encoding"] == "base64" && data["content"].present?
          content = Base64.decode64(data["content"]).force_encoding("UTF-8")

          unless content.valid_encoding?
            Rails.logger.info("[AiReviewer] [project:#{@project.id}] GetFileContent: #{path} is binary (#{data['size']} bytes)")
            return "Binary file: #{path} (#{data['size']} bytes). This file cannot be read as text."
          end

          if start_line || end_line
            all_lines = content.lines
            start_idx = [ (start_line || 1) - 1, 0 ].max
            end_idx = [ (end_line || all_lines.length) - 1, all_lines.length - 1 ].min
            content = all_lines[start_idx..end_idx].join
            range_info = " (lines #{start_idx + 1}-#{end_idx + 1} of #{all_lines.length})"
          else
            range_info = " (#{content.lines.count} lines)"
          end

          truncated = content.length > 30_000
          content = content.truncate(30_000) if truncated

          Rails.logger.info("[AiReviewer] [project:#{@project.id}] GetFileContent: #{path}#{range_info}#{truncated ? ' [TRUNCATED]' : ''} (#{content.length} chars)")
          "# #{path}#{range_info}#{truncated ? ' [TRUNCATED]' : ''}\n\n#{content}"
        else
          Rails.logger.info("[AiReviewer] [project:#{@project.id}] GetFileContent: #{path} is binary (#{data['size']} bytes)")
          "Binary or unsupported file: #{path} (#{data['size']} bytes)"
        end
      rescue StandardError => e
        Rails.logger.error("[AiReviewer] [project:#{@project.id}] GetFileContent error for #{path}: #{e.message}")
        "GitHub API error for #{path}: #{e.message}"
      end
    end
  end
end
