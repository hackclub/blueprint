class LeaderboardsController < ApplicationController
  def index
    @referrals = Rails.cache.fetch("lb:referrals", expires_in: 15.minutes) do
      rows = User.where.not(referrer_id: nil)
                 .where.not(slack_id: [nil, ""])
                 .where(is_mcg: false)
                 .group(:referrer_id)
                 .order(Arel.sql("COUNT(*) DESC"))
                 .limit(10).count
      users = User.where(id: rows.keys).includes(:avatar_attachment).index_by(&:id)
      rows.map { |uid, cnt| [users[uid], cnt] }.compact
    end

    @views = Rails.cache.fetch("lb:views", expires_in: 15.minutes) do
      rows = Project.where(is_deleted: false)
                    .group(:user_id)
                    .select("user_id, SUM(views_count) AS total_views")
                    .order("total_views DESC").limit(10)
      users = User.where(id: rows.map(&:user_id)).includes(:avatar_attachment).index_by(&:id)
      rows.map { |r| [users[r.user_id], r.total_views.to_i] }.compact
    end

    @followers = Rails.cache.fetch("lb:followers", expires_in: 15.minutes) do
      rows = Follow.joins(:project)
                   .where(projects: { is_deleted: false })
                   .group("projects.user_id")
                   .select("projects.user_id AS user_id, COUNT(*) AS followers_count")
                   .order("followers_count DESC").limit(10)
      users = User.where(id: rows.map(&:user_id)).includes(:avatar_attachment).index_by(&:id)
      rows.map { |r| [users[r.user_id], r.followers_count.to_i] }.compact
    end

    @shipped = Rails.cache.fetch("lb:shipped", expires_in: 15.minutes) do
      rows = Project.where(is_deleted: false, review_status: "build_approved")
                    .group(:user_id)
                    .select("user_id, COUNT(*) AS shipped_count")
                    .order("shipped_count DESC").limit(10)
      users = User.where(id: rows.map(&:user_id)).includes(:avatar_attachment).index_by(&:id)
      rows.map { |r| [users[r.user_id], r.shipped_count.to_i] }.compact
    end
  end
end
