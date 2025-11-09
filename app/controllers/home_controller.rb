class HomeController < ApplicationController
  def index
    @projects = current_user.projects.where(is_deleted: false).includes(:banner_attachment)
    @viral_projects = Project.where(viral: true, is_deleted: false)
                             .order_by_recent_journal
                             .limit(10)
                             .includes(:banner_attachment, :latest_journal_entry)

    if current_user.is_pro?
      ip = request.remote_ip
      if Rails.env.development? && (ip == "127.0.0.1" || ip == "::1")
        @show_bp_progress = true
      else
        begin
          geo_data = Geocoder.search(ip).first
          user_country = geo_data&.country_code
          @show_bp_progress = user_country&.upcase == "US"
        rescue => e
          Rails.logger.error("Geocoding failed: #{e.message}")
          @show_bp_progress = false
        end
      end
    else
      @show_bp_progress = false
    end

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
