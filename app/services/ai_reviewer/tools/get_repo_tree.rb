module AiReviewer
  module Tools
    class GetRepoTree < RubyLLM::Tool
      include AiReviewer::GithubClient

      description "Get the file/directory tree of the project's GitHub repository, with file sizes and estimated line counts. Use this to understand the repo structure before reading specific files."

      def initialize(project)
        @project = project
        super()
      end

      def execute(**)
        Rails.logger.info("[AiReviewer] [project:#{@project.id}] Tool call: GetRepoTree")
        parsed = @project.parse_repo
        unless parsed && parsed[:org].present? && parsed[:repo_name].present?
          Rails.logger.info("[AiReviewer] [project:#{@project.id}] GetRepoTree: no GitHub repo linked")
          return "No GitHub repo linked."
        end

        path = "/repos/#{parsed[:org]}/#{parsed[:repo_name]}/git/trees/HEAD?recursive=1"
        response = github_fetch(path)
        unless response.status == 200
          Rails.logger.warn("[AiReviewer] [project:#{@project.id}] GetRepoTree: HTTP #{response.status} from GitHub")
          return "Failed to fetch repo tree (HTTP #{response.status})."
        end

        data = JSON.parse(response.body)
        tree = data["tree"] || []

        file_count = tree.count { |i| i["type"] == "blob" }
        dir_count = tree.count { |i| i["type"] == "tree" }

        lines = []
        lines << "# Repository: #{parsed[:org]}/#{parsed[:repo_name]}"
        lines << "#{file_count} files, #{dir_count} directories\n"

        tree.each do |item|
          if item["type"] == "tree"
            lines << "#{item['path']}/"
          else
            size = item["size"].to_i
            est_lines = size > 0 ? (size / 40.0).ceil : 0
            lines << "#{item['path']} (#{size} bytes, ~#{est_lines} lines)"
          end
        end

        Rails.logger.info("[AiReviewer] [project:#{@project.id}] GetRepoTree: #{file_count} files, #{dir_count} dirs in #{parsed[:org]}/#{parsed[:repo_name]}")
        lines.join("\n")
      rescue StandardError => e
        Rails.logger.error("[AiReviewer] [project:#{@project.id}] GetRepoTree error: #{e.message}")
        "GitHub API error: #{e.message}"
      end
    end
  end
end
