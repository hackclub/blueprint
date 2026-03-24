SitemapGenerator::Sitemap.default_host = "https://blueprint.hackclub.com"
SitemapGenerator::Sitemap.compress = false

SitemapGenerator::Sitemap.create do
  # Static pages
  add explore_path, changefreq: "daily", priority: 0.8
  add guilds_path, changefreq: "daily", priority: 0.7
  add leaderboard_path, changefreq: "daily", priority: 0.5
  add team_path, changefreq: "monthly", priority: 0.4

  # Markdown documentation pages
  %w[about resources starter-projects hackpad].each do |section|
    add "/#{section}", changefreq: "weekly", priority: 0.6

    Dir.glob(Rails.root.join("docs", section, "**/*.md")).each do |file|
      relative = file.sub("#{Rails.root.join("docs", section)}/", "")
      slug = relative.sub(/\.md$/, "").sub(%r{/index$}, "")
      next if slug == "index" || slug.blank?

      add "/#{section}/#{slug}", changefreq: "weekly", priority: 0.5
    end
  end

  # Projects
  Project.active.listed.find_each do |project|
    add project_path(project), lastmod: project.updated_at, changefreq: "weekly", priority: 0.7
  end

  # User profiles (only users with visible projects)
  User.joins(:projects).merge(Project.active.listed).distinct.find_each do |user|
    add user_path(user), changefreq: "weekly", priority: 0.4
  end

  # Guild invite pages
  Guild.open.find_each do |guild|
    add guild_invite_path(slug: guild.invite_slug), changefreq: "weekly", priority: 0.5
  end
end
