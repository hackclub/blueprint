class MarkdownController < ApplicationController
  allow_unauthenticated_access only: %i[ show docs guides faq about resources starter_projects ]
  skip_before_action :set_current_user, if: :turbo_frame_request?

  SECTION_CONFIG = {
    "about" => { suffix: "About Blueprint", index_title: "About - Blueprint" },
    "resources" => { suffix: "Resources", index_title: "Resources - Blueprint" },
    "starter-projects" => { suffix: "Starter Projects", index_title: "Starter Projects - Blueprint" }
  }.freeze

  def about
    render_section("about", params[:slug])
  end

  def resources
    render_section("resources", params[:slug])
  end

  def starter_projects
    render_section("starter-projects", params[:slug])
  end

  # backwards compatibility
  def docs
    redirect_to about_path
  end

  def guides
    redirect_to resources_path
  end

  def faq
    render_from_base Rails.root.join("docs"), "faq", { suffix: "FAQ", index_title: "FAQ - Blueprint", url_prefix: "/faq" }
  end

  private

  def render_section(section, slug)
    config = SECTION_CONFIG[section]
    base = Rails.root.join("docs", section)
    url_prefix = "/#{section}"
    render_from_base(base, slug, config, url_prefix)
  end

  def render_from_base(base, slug, config, url_prefix = nil)
    slug = slug.to_s
    slug = "" if slug.blank?
    not_found unless valid_slug?(slug)

    candidates = if slug.blank?
      [ base.join("index.md") ]
    else
      [ base.join("#{slug}.md"), base.join(slug, "index.md") ]
    end

    path = candidates.find { |p| File.exist?(p.to_s) }
    not_found unless path

    @title = File.basename(path, ".md").presence || "index"
    @content_html = helpers.render_markdown_file(path)

    suffix = config[:suffix] || "Blueprint"
    index_title = config[:index_title] || "Blueprint"

    meta = if url_prefix
      current_url = slug.blank? ? url_prefix : "#{url_prefix}/#{slug}"
      item = helpers.meta_for_url(url_prefix, current_url) rescue nil
      { title: item&.dig(:title), description: item&.dig(:description) }
    else
      begin
        helpers.send(:parse_guide_metadata, path)
      rescue NoMethodError
        { title: nil, description: nil }
      end
    end

    @guide_meta = meta
    if slug.blank?
      @page_title = index_title
    else
      base_title = meta[:title].presence || @title
      @page_title = [ base_title, suffix ].compact.join(" - ")
    end
    @page_description = meta[:description].presence

    if turbo_frame_request?
      render("frame", layout: false)
    else
      render("show")
    end
  end

  def valid_slug?(slug)
    return true if slug == ""
    return false if slug.include?("..") || slug.start_with?("/")

    slug.match?(%r{\A[a-z0-9_\-/]+\z})
  end
end
