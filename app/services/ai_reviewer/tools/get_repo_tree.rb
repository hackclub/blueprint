module AiReviewer
  module Tools
    class GetRepoTree < RubyLLM::Tool
      include AiReviewer::GithubClient

      EXCLUDED_DIRS = Set.new(%w[
        node_modules .git vendor __pycache__ .venv venv dist build
        .next .nuxt .cache .parcel-cache bower_components .terraform
        .gradle target coverage .tox .mypy_cache .pytest_cache
        .idea .vscode
      ]).freeze

      # Files filtered from the tree (available via dedicated tools)
      JOURNAL_PATTERN = /\Ajournal(\.\w+)?\z/i

      # Binary/visual files that should be annotated with tool hints
      VISUAL_TOOL_HINTS = {
        ".step" => "RenderStepFile", ".stp" => "RenderStepFile",
        ".stl" => "RenderStlFile",
        ".kicad_sch" => "ViewKicadSchematic",
        ".kicad_pcb" => "ViewKicadPcb"
      }.freeze

      IMAGE_EXTENSIONS = Set.new(%w[.png .jpg .jpeg .gif .bmp .webp .svg]).freeze

      MAX_ENTRIES = 500

      description "Get the file/directory tree of the project's GitHub repository, with file sizes and estimated line counts. Use this to understand the repo structure before reading specific files."

      def initialize(project)
        @project = project
        @called = false
        super()
      end

      def execute(**)
        Rails.logger.info("[AiReviewer] [project:#{@project.id}] Tool call: GetRepoTree")

        if @called
          return "You already retrieved the repo tree earlier in this review. Refer to the file listing you received previously — do not call this tool again."
        end
        @called = true
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

        original_file_count = tree.count { |i| i["type"] == "blob" }
        original_dir_count = tree.count { |i| i["type"] == "tree" }

        tree = tree.reject { |item| item["path"].split("/").any? { |part| EXCLUDED_DIRS.include?(part) } }

        # Filter out journal files (available via GetJournal tool)
        tree = tree.reject { |item| item["type"] == "blob" && File.basename(item["path"]) =~ JOURNAL_PATTERN }

        file_count = tree.count { |i| i["type"] == "blob" }
        dir_count = tree.count { |i| i["type"] == "tree" }
        total_entries = tree.size
        truncated = total_entries > MAX_ENTRIES

        tree = tree.first(MAX_ENTRIES) if truncated

        lines = []
        lines << "# Repository: #{parsed[:org]}/#{parsed[:repo_name]}"
        lines << "#{file_count} files, #{dir_count} directories (#{original_file_count} files, #{original_dir_count} directories before filtering excluded dirs)"
        lines << "Note: Journal files are excluded as the contents are already given.\n"

        tree.each do |item|
          if item["type"] == "tree"
            lines << "#{item['path']}/"
          else
            size = item["size"].to_i
            path = item["path"]
            ext = File.extname(path).downcase

            if VISUAL_TOOL_HINTS.key?(ext)
              tool = VISUAL_TOOL_HINTS[ext]
              lines << "#{path} (#{size} bytes) [binary — use #{tool} to view]"
            elsif IMAGE_EXTENSIONS.include?(ext)
              lines << "#{path} (#{size} bytes) [image — use GetImage to view]"
            else
              est_lines = size > 0 ? (size / 40.0).ceil : 0
              lines << "#{path} (#{size} bytes, ~#{est_lines} lines)"
            end
          end
        end

        lines << "\n(Showing #{MAX_ENTRIES} of #{total_entries} entries. Tree was truncated.)" if truncated

        Rails.logger.info("[AiReviewer] [project:#{@project.id}] GetRepoTree: #{file_count} files, #{dir_count} dirs (filtered from #{original_file_count}/#{original_dir_count}) in #{parsed[:org]}/#{parsed[:repo_name]}")
        lines.join("\n")
      rescue StandardError => e
        Rails.logger.error("[AiReviewer] [project:#{@project.id}] GetRepoTree error: #{e.message}")
        "GitHub API error. Try again later."
      end
    end
  end
end
