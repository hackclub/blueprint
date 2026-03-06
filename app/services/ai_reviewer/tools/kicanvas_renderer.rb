require "vips"

module AiReviewer
  module Tools
    module KicanvasRenderer
      KICANVAS_BASE = "https://kicanvas.org/".freeze
      RENDER_TIMEOUT = 45
      VIEWPORT_WIDTH = 1400
      VIEWPORT_HEIGHT = 1000

      private

      def render_kicanvas(github_file_url)
        kicanvas_url = "#{KICANVAS_BASE}?github=#{ERB::Util.url_encode(github_file_url)}"

        browser = Ferrum::Browser.new(
          browser_path: ENV.fetch("CHROMIUM_PATH", "/usr/bin/chromium"),
          timeout: RENDER_TIMEOUT,
          window_size: [VIEWPORT_WIDTH, VIEWPORT_HEIGHT],
          headless: "new",
          browser_options: {
            "no-sandbox" => nil,
            "disable-dev-shm-usage" => nil,
            "use-gl" => "angle",
            "use-angle" => "swiftshader"
          }
        )

        begin
          browser.goto(kicanvas_url)

          # Wait for all network requests to complete (GitHub file fetch + WASM load).
          # KiCanvas uses Shadow DOM so we can't query its internals directly.
          # duration: 2 means "idle for 2 consecutive seconds before considering done".
          browser.network.wait_for_idle(connections: 0, duration: 2, timeout: RENDER_TIMEOUT)

          screenshot_data = browser.screenshot(encoding: :binary)

          image = Vips::Image.new_from_buffer(screenshot_data, "")
          if image.width > 1000 || image.height > 1000
            image = image.thumbnail_image(1000, height: 1000, size: :down)
          end

          jpeg_data = image.jpegsave_buffer(Q: 80)
          tempfile = Tempfile.new(["kicanvas_render", ".jpg"])
          tempfile.binmode
          tempfile.write(jpeg_data)
          tempfile.flush

          { tempfile: tempfile, width: image.width, height: image.height, size: jpeg_data.bytesize }
        ensure
          browser.quit
        end
      end
    end
  end
end
