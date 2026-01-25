class WarmMarkdownCacheJob < ApplicationJob
  include MarkdownHelper

  queue_as :background

  def perform
    base_url = MarkdownHelper.canonical_base_url
    docs_base = Rails.root.join("docs")

    Dir.glob(docs_base.join("**/*.md").to_s).each do |path|
      render_markdown_file(path, base_url: base_url)
    rescue => e
      Sentry.capture_exception("WarmMarkdownCacheJob: Failed to cache #{path}: #{e.message}")
      Rails.logger.warn("WarmMarkdownCacheJob: Failed to cache #{path}: #{e.message}")
    end

    Rails.logger.info("WarmMarkdownCacheJob: Warmed cache for #{Dir.glob(docs_base.join('**/*.md')).count} markdown files")
  end
end
