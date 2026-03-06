require "vips"

module AiReviewer
  module Tools
    class RenderStepFile < RubyLLM::Tool
      include AiReviewer::GithubClient

      description "Render a STEP file (.step or .stp) from the repository as a 3D image. ONLY use this when no existing renders or screenshots of the 3D model are available in the repository — always check the README and image files first. This is an expensive operation."

      params do
        string :path, description: "Path to the STEP file in the repository (e.g. 'cad/assembly.step')"
        string :camera_angle, description: "Camera angle: 'front', 'top', 'right', 'isometric' (default: 'isometric')", required: false
      end

      RENDER_TIMEOUT = 45
      VIEWPORT_WIDTH = 1200
      VIEWPORT_HEIGHT = 900
      MAX_FILE_SIZE = 1.megabyte

      def initialize(project, seen_resources: nil)
        @project = project
        @seen_resources = seen_resources
        super()
      end

      VALID_ANGLES = %w[front top right isometric].freeze

      def execute(path:, camera_angle: "isometric")
        camera_angle = VALID_ANGLES.include?(camera_angle) ? camera_angle : "isometric"
        Rails.logger.info("[AiReviewer] [project:#{@project.id}] Tool call: RenderStepFile(#{path}, angle: #{camera_angle})")

        key = "render:#{path}:#{camera_angle}"
        if @seen_resources&.include?(key)
          return "Already rendered #{path} (#{camera_angle}) — use the image from the earlier call."
        end

        parsed = @project.parse_repo
        unless parsed && parsed[:org].present? && parsed[:repo_name].present?
          return "No GitHub repo linked."
        end

        unless path.downcase.end_with?(".step", ".stp")
          return "Invalid file: #{path} is not a STEP file (.step or .stp)."
        end

        # Download STEP file from GitHub
        encoded_path = path.split("/").map { |s| ERB::Util.url_encode(s) }.join("/")
        api_path = "/repos/#{parsed[:org]}/#{parsed[:repo_name]}/contents/#{encoded_path}"
        response = github_fetch(api_path)
        unless response.status == 200
          return "STEP file not found: #{path} (HTTP #{response.status})."
        end

        data = JSON.parse(response.body)
        file_size = data["size"].to_i
        if file_size > MAX_FILE_SIZE
          return "STEP file too large: #{path} (#{(file_size / 1.megabyte.to_f).round(1)} MB, max #{MAX_FILE_SIZE / 1.megabyte} MB)."
        end

        step_content = Base64.decode64(data["content"])

        # Save STEP to tempfile
        step_file = Tempfile.new(["step_model", ".step"])
        step_file.binmode
        step_file.write(step_content)
        step_file.flush

        # Render via headless Chromium + Three.js
        renderer_html = Rails.root.join("app/services/ai_reviewer/tools/step_renderer.html").read

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
          # Load the renderer HTML from a temp file (not data: URI)
          # so that occt-import-js can resolve its WASM file correctly
          html_file = Tempfile.new(["step_renderer", ".html"])
          html_file.write(renderer_html)
          html_file.flush
          browser.goto("file://#{html_file.path}")

          # Inject the STEP file data and camera angle
          step_base64 = Base64.strict_encode64(step_content)
          browser.execute("window.stepFileBase64 = #{JSON.generate(step_base64)};")
          browser.execute("window.cameraAngle = #{JSON.generate(camera_angle)};")
          browser.execute("window._renderDone = false; if (typeof loadAndRender === 'function') loadAndRender().then(() => { window._renderDone = true; }).catch(() => { window._renderDone = true; });")

          # Poll until render completes (up to RENDER_TIMEOUT)
          Timeout.timeout(RENDER_TIMEOUT) do
            loop do
              break if browser.evaluate("window._renderDone")
              sleep 0.5
            end
          end

          js_error = browser.evaluate("window._renderError")
          if js_error
            Rails.logger.error("[AiReviewer] [project:#{@project.id}] STEP JS render error: #{js_error}")
            return "Failed to render STEP file #{path}: #{js_error}"
          end

          screenshot_data = browser.screenshot(encoding: :binary)

          # Process with libvips
          image = Vips::Image.new_from_buffer(screenshot_data, "")
          if image.width > 1000 || image.height > 1000
            image = image.thumbnail_image(1000, height: 1000, size: :down)
          end

          jpeg_data = image.jpegsave_buffer(Q: 80)
          tempfile = Tempfile.new(["step_render", ".jpg"])
          tempfile.binmode
          tempfile.write(jpeg_data)
          tempfile.flush

          description = "3D render of #{path} (#{camera_angle} view, #{image.width}x#{image.height})"
          Rails.logger.info("[AiReviewer] [project:#{@project.id}] RenderStepFile: rendered #{path} (#{jpeg_data.bytesize} bytes)")

          @seen_resources&.add(key)
          content = RubyLLM::Content.new(description, [tempfile.path])
          content.instance_variable_set(:@_tempfiles, [tempfile])
          content
        ensure
          browser.quit
          step_file.close!
          html_file.close!
        end
      rescue StandardError => e
        Rails.logger.error("[AiReviewer] [project:#{@project.id}] RenderStepFile error: #{e.message}")
        "Failed to render STEP file #{path}."
      end
    end
  end
end
