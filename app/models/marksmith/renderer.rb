module Marksmith
  # Local override of the gem's renderer with:
  # - Redcarpet configured without underline
  # - External links open in new tab (rel="nofollow noopener" target="_blank"), internal links stay same tab
  # - Optional callouts preprocessing for <aside> blocks
  # - Optimized image variants for Active Storage blobs (2000px max, WebP @ 80%)
  class Renderer
    WEB_IMAGE_VARIANT_OPTIONS = {
      resize_to_limit: [ 2000, 2000 ],
      convert: :webp,
      saver: { quality: 80, strip: true }
    }.freeze

    def initialize(body:, base_url: nil)
      @body = body.to_s.dup.force_encoding("utf-8")
      @base_url = base_url
    end

    def render
      markdown.render(preprocess_callouts(@body))
    end

    private

    def markdown
      html_renderer = LinkRenderer.new(base_url: @base_url, hard_wrap: true, with_toc_data: true, prettify: true)

      ::Redcarpet::Markdown.new(
        html_renderer,
        autolink: true,
        tables: true,
        fenced_code_blocks: true,
        strikethrough: true,
        lax_spacing: true,
        space_after_headers: true,
        footnotes: false,
        no_intra_emphasis: false,
        no_html: true
      )
    end

    def preprocess_callouts(text)
      return text unless text.include?("<aside")
      text.gsub(%r{<aside(\s[^>]*)?>\s*(.*?)\s*</aside>}m) do
        attrs = Regexp.last_match(1).to_s
        inner_md = Regexp.last_match(2)
        inner_html = markdown.render(inner_md)
        "<aside#{attrs}>#{inner_html}</aside>"
      end
    end

    class LinkRenderer < Redcarpet::Render::HTML
      include Rails.application.routes.url_helpers

      def initialize(options = {})
        @base_url = options.delete(:base_url)
        super(options)
      end

      def image(src, title, alt_text)
        optimized_src = optimize_image_src(src)

        attrs = []
        attrs << %(src="#{ERB::Util.html_escape(optimized_src)}")
        attrs << %(alt="#{ERB::Util.html_escape(alt_text)}") if alt_text.present?
        attrs << %(title="#{ERB::Util.html_escape(title)}") if title.present?
        attrs << %(loading="lazy")

        "<img #{attrs.join(' ')} />"
      end

      def link(href, title, content)
        href = href.to_s
        # Fallback: if href is blank or the default placeholder ("url"), try to derive from the label
        if href.strip.empty? || href.strip.downcase == "url"
          candidate = content.to_s.strip
          if candidate.start_with?("/", "./", "../", "#") || candidate =~ %r{\Ahttps?://}i
            href = candidate
          end
        end

        attrs = []
        attrs << %(href="#{ERB::Util.html_escape(href)}")
        attrs << %(title="#{ERB::Util.html_escape(title)}") if title

        if external_link?(href)
          attrs << %(target="_blank")
          attrs << %(rel="nofollow noopener")
        end

        "<a #{attrs.join(' ')}>#{content}</a>"
      end

      # Handle bare autolinks (e.g., https://example.com) so they get rel/target too
      def autolink(link, link_type)
        href = link.to_s
        if link_type == :email
          return %(<a href="mailto:#{ERB::Util.html_escape(href)}">#{ERB::Util.html_escape(href)}</a>)
        end
        attrs = []
        attrs << %(href="#{ERB::Util.html_escape(href)}")
        if external_link?(href)
          attrs << %(target="_blank")
          attrs << %(rel="nofollow noopener")
        end
        %(<a #{attrs.join(' ')}>#{ERB::Util.html_escape(href)}</a>)
      end

      private

      def external_link?(href)
        # anchors or relative paths are internal
        return false if href.start_with?("#", "/", "./", "../")
        # absolute URL with scheme
        return false unless href =~ %r{\Ahttps?://}i
        return true unless @base_url
        begin
          base = URI.parse(@base_url)
          u = URI.parse(href)
          (base.scheme != u.scheme) || (base.host != u.host) || ((base.port || default_port(base.scheme)) != (u.port || default_port(u.scheme)))
        rescue URI::InvalidURIError
          true
        end
      end

      def default_port(scheme)
        scheme.to_s.downcase == "https" ? 443 : 80
      end

      def optimize_image_src(src)
        return src unless local_active_storage_blob?(src)

        blob = find_blob_from_url(src)
        return src unless blob&.image?

        variant = blob.variant(Renderer::WEB_IMAGE_VARIANT_OPTIONS)
        rails_representation_url(variant, host: host_for_urls)
      rescue => e
        Rails.logger.error("Failed to generate optimized image variant for #{src}: #{e.message}")
        src
      end

      def local_active_storage_blob?(src)
        src.to_s.include?("/rails/active_storage/blobs/") ||
          src.to_s.include?("/user-attachments/blobs/")
      end

      def find_blob_from_url(src)
        # Standard ActiveStorage URLs
        if (match = src.match(%r{/rails/active_storage/blobs/(?:redirect/|proxy/)?([^/]+)/}))
          return ActiveStorage::Blob.find_signed(match[1])
        end

        # Marksmith/user-attachments URLs (Base64-encoded JSON with blob_id)
        if (match = src.match(%r{/user-attachments/blobs/(?:redirect/|proxy/)?([^/]+)/}))
          token = match[1].split("--").first
          decoded = JSON.parse(Base64.decode64(token))
          blob_id = decoded.dig("_rails", "data") || decoded["data"]
          return ActiveStorage::Blob.find_by(id: blob_id)
        end

        nil
      rescue ActiveSupport::MessageVerifier::InvalidSignature, JSON::ParserError, ArgumentError
        nil
      end

      def host_for_urls
        ENV.fetch("APPLICATION_HOST", Rails.application.routes.default_url_options[:host] || "localhost:3000")
      end
    end
  end
end
