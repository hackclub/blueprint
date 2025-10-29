class LeaderboardsController < ApplicationController
  def index
    @referrals = Rails.cache.fetch("lb:referrals", expires_in: 15.minutes) do
      rows = User.where.not(referrer_id: nil)
                 .where.not(slack_id: [ nil, "" ])
                 .where(is_mcg: false)
                 .group(:referrer_id)
                 .order(Arel.sql("COUNT(*) DESC"))
                 .limit(10).count
      users = User.where(id: rows.keys).index_by(&:id)
      rows.map { |uid, cnt| [ users[uid], cnt ] }.compact
    end

    @views = Rails.cache.fetch("lb:views", expires_in: 15.minutes) do
      rows = Project.joins(:user)
                    .where(is_deleted: false)
                    .group(:user_id)
                    .select("user_id, SUM(views_count) AS total_views")
                    .order("total_views DESC").limit(10)
      users = User.where(id: rows.map(&:user_id)).index_by(&:id)
      rows.map { |r| [ users[r.user_id], r.total_views.to_i ] }.compact
    end

    @followers = Rails.cache.fetch("lb:followers", expires_in: 15.minutes) do
      rows = Follow.joins(:project)
                   .where(projects: { is_deleted: false })
                   .group("projects.user_id")
                   .select("projects.user_id AS user_id, COUNT(*) AS followers_count")
                   .order("followers_count DESC").limit(10)
      users = User.where(id: rows.map(&:user_id)).index_by(&:id)
      rows.map { |r| [ users[r.user_id], r.followers_count.to_i ] }.compact
    end

    @shipped = Rails.cache.fetch("lb:shipped", expires_in: 15.minutes) do
      rows = Project.joins(:user)
                    .where(is_deleted: false, review_status: "build_approved")
                    .group(:user_id)
                    .select("user_id, COUNT(*) AS shipped_count")
                    .order("shipped_count DESC").limit(10)
      users = User.where(id: rows.map(&:user_id)).index_by(&:id)
      rows.map { |r| [ users[r.user_id], r.shipped_count.to_i ] }.compact
    end

    @approved_hours = Rails.cache.fetch("lb:approved_hours_v2", expires_in: 15.minutes) do
      rows = Project
               .joins(:design_reviews)
               .where(is_deleted: false)
               .where(design_reviews: { invalidated: false, admin_review: true, result: 0 })
               .group(:user_id)
               .select("projects.user_id, SUM(COALESCE(design_reviews.hours_override::numeric, design_reviews.frozen_duration_seconds::numeric/3600.0)) AS approved_hours")
               .order("approved_hours DESC")
               .limit(10)
      users = User.where(id: rows.map(&:user_id)).index_by(&:id)
      rows.map { |r| [ users[r.user_id], r.approved_hours.to_f.round(1) ] }.compact
    end

    @first_pass_reviews = Rails.cache.fetch("lb:first_pass", expires_in: 15.minutes) do
      rows = DesignReview.find_by_sql(<<~SQL)
        SELECT reviewer_id, COUNT(*) AS first_pass_count
        FROM (
          SELECT DISTINCT ON (project_id) id, project_id, reviewer_id
          FROM design_reviews
          WHERE invalidated = false
            AND COALESCE(admin_review, false) = false
          ORDER BY project_id, created_at ASC, id ASC
        ) firsts
        GROUP BY reviewer_id
        ORDER BY first_pass_count DESC
        LIMIT 10
      SQL
      user_ids = rows.map(&:reviewer_id)
      users = User.where(id: user_ids).index_by(&:id)
      rows.map { |r| [ users[r.reviewer_id], r.first_pass_count.to_i ] }.compact
    end
  end
end
