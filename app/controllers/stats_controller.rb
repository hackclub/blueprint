class StatsController < ApplicationController
  allow_unauthenticated_access

  def index
    @hide_nav = true

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

    @total_countries = cached("stats:total_countries") {
      User.where.not(idv_country: [ nil, "" ]).distinct.count(:idv_country)
    }

    @active_guilds = cached("stats:active_guilds") {
      Guild.where(status: "active").count
    }

    @top_countries = cached("stats:top_countries") {
      User.where.not(idv_country: [ nil, "" ])
        .group(:idv_country)
        .order(Arel.sql("COUNT(*) DESC"))
        .limit(10)
        .count
    }

    @projects_by_state = cached("stats:projects_by_state") {
      active = Project.where(is_deleted: false).where.not(review_status: nil)
      {
        "In Design Review" => active.where(review_status: [ "design_pending", "design_needs_revision" ]).count,
        "Design Approved" => active.where(review_status: "design_approved").count,
        "In Build Review" => active.where(review_status: [ "build_pending", "build_needs_revision" ]).count,
        "Shipped" => active.where(review_status: "build_approved").count
      }
    }

    @avg_hours_per_project = cached("stats:avg_hours_per_project") {
      avg = Project.joins(:journal_entries)
        .where(is_deleted: false)
        .group("projects.id")
        .select("projects.id, SUM(journal_entries.duration_seconds) / 3600.0 AS total_hours")
        .map(&:total_hours)
      avg.any? ? (avg.sum / avg.size).round(1) : 0
    }

    @total_followers = cached("stats:total_followers") {
      Follow.count
    }

    # Fetch recent shipped projects for the gallery
    @gallery_projects = cached("stats:gallery_projects") {
      Project.where(is_deleted: false, unlisted: false)
        .where.not(review_status: nil)
        .order(views_count: :desc)
        .limit(12)
        .to_a
    }
  end

  private

  def cached(key, &block)
    Rails.cache.fetch(key, expires_in: 15.minutes, race_condition_ttl: 2.minutes, &block)
  end
end
