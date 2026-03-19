class Admin::GuildsController < Admin::ApplicationController
  skip_before_action :require_admin!
  before_action :require_reviewer_perms!

  def index
    @q = params[:q].to_s.strip

    guilds = Guild.includes(:guild_signups).order(created_at: :desc)

    if @q.present?
      like = "%#{@q}%"
      guilds = guilds.where(
        "guilds.city ILIKE :q OR guilds.country ILIKE :q OR guilds.name ILIKE :q",
        q: like
      )
    end

    @pagy, @guilds = pagy(guilds, items: 20)
  end

  def show
    @guild = Guild.includes(guild_signups: :user).find(params[:id])
  end

  private

  def require_reviewer_perms!
    unless current_user&.reviewer_perms?
      redirect_to main_app.root_path, alert: "You are not authorized to access this page."
    end
  end
end
