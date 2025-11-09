class HomeController < ApplicationController
  def index
    @projects = current_user.projects.where(is_deleted: false).includes(:banner_attachment)
    @viral_projects = Project.where(viral: true, is_deleted: false)
                             .order_by_recent_journal
                             .limit(10)
                             .includes(:banner_attachment, :latest_journal_entry)

    last_country = current_user.ahoy_visits.order(started_at: :desc).limit(1).pick(:country)
    @show_bp_progress = current_user.is_pro? && last_country == "US"

    if @show_bp_progress
      weights = { 1 => 60, 2 => 50, 3 => 40, 4 => 30, 5 => 20 }
      approved = current_user.projects
                  .where(is_deleted: false)
                  .where(review_status: [ "design_approved", "build_approved" ])
                  .select(:tier, :approved_tier)
      @bp_progress = approved.sum do |p|
        t = (p.approved_tier.presence || p.tier).to_i
        weights[t] || 0
      end
    end
  end
end
