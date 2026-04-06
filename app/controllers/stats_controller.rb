class StatsController < ApplicationController
  allow_unauthenticated_access

  def index
    @total_projects = cached("stats:total_projects") {
      Project.where(is_deleted: false).count
    }

    @total_users = cached("stats:total_users") {
      User.count
    }

    @total_hours = cached("stats:total_hours") {
      (JournalEntry.sum(:duration_seconds) / 3600.0).round(1)
    }

    @total_journal_entries = cached("stats:total_journal_entries") {
      JournalEntry.count
    }

    @shipped_projects = cached("stats:shipped_projects") {
      Project.where(is_deleted: false, review_status: "build_approved").count
    }

    @total_kudos = cached("stats:total_kudos") {
      Kudo.count
    }

    @total_countries = cached("stats:total_countries") {
      User.where.not(country: [ nil, "" ]).distinct.count(:country)
    }

    @active_guilds = cached("stats:active_guilds") {
      Guild.where(status: "active").count
    }

    @projects_over_time = cached("stats:projects_over_time") {
      Project.where(is_deleted: false)
        .where("created_at > ?", 6.months.ago)
        .group(Arel.sql("DATE_TRUNC('week', created_at)"))
        .order(Arel.sql("DATE_TRUNC('week', created_at)"))
        .count
        .transform_keys { |k| k.strftime("%b %d") }
    }

    @entries_over_time = cached("stats:entries_over_time") {
      JournalEntry
        .where("created_at > ?", 6.months.ago)
        .group(Arel.sql("DATE_TRUNC('week', created_at)"))
        .order(Arel.sql("DATE_TRUNC('week', created_at)"))
        .count
        .transform_keys { |k| k.strftime("%b %d") }
    }

    @projects_by_status = cached("stats:projects_by_status") {
      Project.where(is_deleted: false)
        .where.not(review_status: nil)
        .group(:review_status)
        .count
        .transform_keys { |k| k.to_s.titleize.gsub("Build ", "").gsub("Design ", "") }
    }

    @projects_by_tier = cached("stats:projects_by_tier") {
      Project.where(is_deleted: false)
        .where.not(tier: nil)
        .group(:tier)
        .count
        .transform_keys { |k| "Tier #{k}" }
    }

    @top_countries = cached("stats:top_countries") {
      User.where.not(country: [ nil, "" ])
        .group(:country)
        .order(Arel.sql("COUNT(*) DESC"))
        .limit(10)
        .count
    }
  end

  private

  def cached(key, &block)
    Rails.cache.fetch(key, expires_in: 15.minutes, race_condition_ttl: 2.minutes, &block)
  end
end
