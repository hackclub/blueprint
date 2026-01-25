class HomeController < ApplicationController
  def index
    @projects = current_user.projects.where(is_deleted: false).includes(:banner_attachment)
    @viral_projects = Project.where(viral: true, is_deleted: false)
                             .order_by_recent_journal
                             .limit(10)
                             .includes(:banner_attachment, :latest_journal_entry)

    #   # if current_user.is_pro?
    #   ip = request.remote_ip
    #   if Rails.env.development? && (ip == "127.0.0.1" || ip == "::1")
    #     @show_bp_progress = true
    #   else
    #     @show_bp_progress = us_ip?(ip)
    #   end
    # # else
    # #   @show_bp_progress = false
    # # end

    # # if @show_bp_progress
    # weights = { 1 => 100, 2 => 100, 3 => 100, 4 => 50, 5 => 25 }
    # approved = current_user.projects
    #             .where(review_status: [ "design_approved", "build_approved" ])
    #             .select(:tier, :approved_tier)
    # @bp_progress = approved.sum do |p|
    #   t = (p.approved_tier.presence || p.tier).to_i
    #   weights[t] || 0
    # end
    # @bp_progress = @bp_progress.to_i.clamp(0, 100)
    # # end
  end

  private

  # def us_ip?(ip)
  #   return false if ip.blank?

  #   ipaddr = IPAddr.new(ip) rescue nil
  #   return false if ipaddr&.private? || ipaddr&.loopback? || ipaddr&.link_local?

  #   country = Rails.cache.fetch("geo:#{ip}", expires_in: 12.hours, race_condition_ttl: 30.minutes) do
  #     Timeout.timeout(0.5) do
  #       Geocoder.search(ip).first&.country_code&.upcase
  #     end
  #   rescue => e
  #     Rails.logger.warn("Geocoding failed: #{e.class}")
  #     nil
  #   end

  #   country == "US" || country == "United States"
  # end
end
