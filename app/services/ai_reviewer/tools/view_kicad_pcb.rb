require "vips"

module AiReviewer
  module Tools
    class ViewKicadPcb < RubyLLM::Tool
      include AiReviewer::GithubClient
      include AiReviewer::Tools::KicanvasRenderer

      description "Render a KiCad PCB layout (.kicad_pcb) file as an image for visual inspection. ONLY use this when no existing screenshots of the PCB layout are available in the repository — always check the README and image files first. This is an expensive operation."

      params do
        string :path, description: "Path to the .kicad_pcb file in the repository (e.g. 'pcb/project.kicad_pcb')"
      end

      def initialize(project, seen_resources: nil)
        @project = project
        @seen_resources = seen_resources
        super()
      end

      def execute(path:)
        Rails.logger.info("[AiReviewer] [project:#{@project.id}] Tool call: ViewKicadPcb(#{path})")

        key = "render:#{path}"
        if @seen_resources&.include?(key)
          return "Already rendered #{path} — use the image from the earlier call."
        end

        parsed = @project.parse_repo
        unless parsed && parsed[:org].present? && parsed[:repo_name].present?
          return "No GitHub repo linked."
        end

        unless path.end_with?(".kicad_pcb")
          return "Invalid file: #{path} is not a .kicad_pcb file."
        end

        github_url = "https://github.com/#{parsed[:org]}/#{parsed[:repo_name]}/blob/HEAD/#{path}"
        result = render_kicanvas(github_url)

        description = "KiCad PCB layout: #{path} (#{result[:width]}x#{result[:height]}, #{result[:size]} bytes)"
        Rails.logger.info("[AiReviewer] [project:#{@project.id}] ViewKicadPcb: rendered #{path}")

        @seen_resources&.add(key)
        content = RubyLLM::Content.new(description, [result[:tempfile].path])
        content.instance_variable_set(:@_tempfiles, [result[:tempfile]])
        content
      rescue StandardError => e
        Rails.logger.error("[AiReviewer] [project:#{@project.id}] ViewKicadPcb error: #{e.message}")
        "Failed to render PCB layout #{path}."
      end
    end
  end
end
