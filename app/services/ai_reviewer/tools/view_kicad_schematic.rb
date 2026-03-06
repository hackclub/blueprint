require "vips"

module AiReviewer
  module Tools
    class ViewKicadSchematic < RubyLLM::Tool
      include AiReviewer::GithubClient
      include AiReviewer::Tools::KicanvasRenderer

      description "Render a KiCad schematic (.kicad_sch) file as an image for visual inspection. ONLY use this when no existing screenshots of the schematic are available in the repository — always check the README and image files first. This is an expensive operation."

      params do
        string :path, description: "Path to the .kicad_sch file in the repository (e.g. 'pcb/project.kicad_sch')"
      end

      def initialize(project, seen_resources: nil)
        @project = project
        @seen_resources = seen_resources
        super()
      end

      def execute(path:)
        Rails.logger.info("[AiReviewer] [project:#{@project.id}] Tool call: ViewKicadSchematic(#{path})")

        key = "render:#{path}"
        if @seen_resources&.include?(key)
          return "Already rendered #{path} — use the image from the earlier call."
        end

        parsed = @project.parse_repo
        unless parsed && parsed[:org].present? && parsed[:repo_name].present?
          return "No GitHub repo linked."
        end

        unless path.end_with?(".kicad_sch")
          return "Invalid file: #{path} is not a .kicad_sch file."
        end

        github_url = "https://github.com/#{parsed[:org]}/#{parsed[:repo_name]}/blob/HEAD/#{path}"
        result = render_kicanvas(github_url)

        description = "KiCad schematic: #{path} (#{result[:width]}x#{result[:height]}, #{result[:size]} bytes)"
        Rails.logger.info("[AiReviewer] [project:#{@project.id}] ViewKicadSchematic: rendered #{path}")

        @seen_resources&.add(key)
        content = RubyLLM::Content.new(description, [result[:tempfile].path])
        content.instance_variable_set(:@_tempfiles, [result[:tempfile]])
        content
      rescue StandardError => e
        Rails.logger.error("[AiReviewer] [project:#{@project.id}] ViewKicadSchematic error: #{e.message}")
        "Failed to render schematic #{path}."
      end
    end
  end
end
