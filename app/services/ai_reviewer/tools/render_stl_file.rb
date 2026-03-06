require "vips"

module AiReviewer
  module Tools
    class RenderStlFile < RubyLLM::Tool
      include AiReviewer::GithubClient

      description "Render an STL file (.stl) from the repository as a 3D image. ONLY use this when no existing renders or screenshots of the 3D model are available in the repository — always check the README and image files first. This is an expensive operation."

      params do
        string :path, description: "Path to the STL file in the repository (e.g. 'cad/enclosure.stl')"
        string :camera_angle, description: "Camera angle: 'front', 'top', 'right', 'isometric' (default: 'isometric')", required: false
      end

      RENDER_TIMEOUT = 45
      VIEWPORT_WIDTH = 1200
      VIEWPORT_HEIGHT = 900
      MAX_FILE_SIZE = 5.megabytes

      def initialize(project, seen_resources: nil)
        @project = project
        @seen_resources = seen_resources
        super()
      end

      VALID_ANGLES = %w[front top right isometric].freeze

      def execute(path:, camera_angle: "isometric")
        camera_angle = VALID_ANGLES.include?(camera_angle) ? camera_angle : "isometric"
        Rails.logger.info("[AiReviewer] [project:#{@project.id}] Tool call: RenderStlFile(#{path}, angle: #{camera_angle})")

        key = "render:#{path}:#{camera_angle}"
        if @seen_resources&.include?(key)
          return "Already rendered #{path} (#{camera_angle}) — use the image from the earlier call."
        end

        parsed = @project.parse_repo
        unless parsed && parsed[:org].present? && parsed[:repo_name].present?
          return "No GitHub repo linked."
        end

        unless path.downcase.end_with?(".stl")
          return "Invalid file: #{path} is not an STL file (.stl)."
        end

        # Download STL file from GitHub
        encoded_path = path.split("/").map { |s| ERB::Util.url_encode(s) }.join("/")
        api_path = "/repos/#{parsed[:org]}/#{parsed[:repo_name]}/contents/#{encoded_path}"
        response = github_fetch(api_path)
        unless response.status == 200
          return "STL file not found: #{path} (HTTP #{response.status})."
        end

        data = JSON.parse(response.body)
        file_size = data["size"].to_i
        if file_size > MAX_FILE_SIZE
          return "STL file too large: #{path} (#{(file_size / 1.megabyte.to_f).round(1)} MB, max #{MAX_FILE_SIZE / 1.megabyte} MB)."
        end

        stl_content = Base64.decode64(data["content"])

        # Save STL to tempfile
        stl_file = Tempfile.new(["stl_model", ".stl"])
        stl_file.binmode
        stl_file.write(stl_content)
        stl_file.flush

        # Render via headless Chromium + Three.js
        renderer_html = Rails.root.join("app/services/ai_reviewer/tools/stl_renderer.html").read

        browser = Ferrum::Browser.new(
          browser_path: ENV.fetch("CHROMIUM_PATH", "/usr/bin/chromium"),
          timeout: RENDER_TIMEOUT,
          window_size: [VIEWPORT_WIDTH, VIEWPORT_HEIGHT],
          headless: "new",
          browser_options: {
            "no-sandbox" => nil,
            "disable-dev-shm-usage" => nil,
            "allow-file-access-from-files" => nil,
            "use-gl" => "angle",
            "use-angle" => "swiftshader"
          }
        )

        begin
          # Load the renderer HTML as a data URI
          encoded_html = Base64.strict_encode64(renderer_html)
          browser.goto("data:text/html;base64,#{encoded_html}")

          # Inject the STL file data and camera angle
          stl_base64 = Base64.strict_encode64(stl_content)
          browser.execute("window.stlFileBase64 = #{JSON.generate(stl_base64)};")
          browser.execute("window.cameraAngle = #{JSON.generate(camera_angle)};")
          browser.execute("window._renderDone = false; if (typeof loadAndRender === 'function') loadAndRender().then(() => { window._renderDone = true; }).catch(() => { window._renderDone = true; });")

          # Poll until render completes (up to RENDER_TIMEOUT)
          Timeout.timeout(RENDER_TIMEOUT) do
            loop do
              break if browser.evaluate("window._renderDone")
              sleep 0.5
            end
          end

          screenshot_data = browser.screenshot(encoding: :binary)

          # Process with libvips
          image = Vips::Image.new_from_buffer(screenshot_data, "")
          if image.width > 1000 || image.height > 1000
            image = image.thumbnail_image(1000, height: 1000, size: :down)
          end

          jpeg_data = image.jpegsave_buffer(Q: 80)
          tempfile = Tempfile.new(["stl_render", ".jpg"])
          tempfile.binmode
          tempfile.write(jpeg_data)
          tempfile.flush

          description = "3D render of #{path} (#{camera_angle} view, #{image.width}x#{image.height})"
          Rails.logger.info("[AiReviewer] [project:#{@project.id}] RenderStlFile: rendered #{path} (#{jpeg_data.bytesize} bytes)")

          @seen_resources&.add(key)
          content = RubyLLM::Content.new(description, [tempfile.path])
          content.instance_variable_set(:@_tempfiles, [tempfile])
          content
        ensure
          browser.quit
          stl_file.close!
        end
      rescue StandardError => e
        Rails.logger.error("[AiReviewer] [project:#{@project.id}] RenderStlFile error: #{e.message}")
        "Failed to render STL file #{path}."
      end
    end
  end
end
