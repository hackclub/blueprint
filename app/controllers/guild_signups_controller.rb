class GuildSignupsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_guild, only: [ :create ]

  def new
    @signup = GuildSignup.new
  end

  def create
    @signup = current_user.guild_signups.build(signup_params)
    @signup.guild = @guild

    if @signup.save
      redirect_to guilds_path, notice: "Thanks for signing up! We'll be in touch soon."
    else
      @guilds_page = true
      render "guilds/index", status: :unprocessable_entity
    end
  end

  private

  def signup_params
    params.require(:guild_signup).permit(:role, :name, :email, :ideas)
  end

  def set_guild
    city = params[:guild_signup][:city]&.strip
    if city.blank?
      @signup = current_user.guild_signups.build(signup_params)
      @signup.errors.add(:city, "can't be blank")
      render "guilds/index", status: :unprocessable_entity and return
    end
    @guild = Guild.find_or_create_by(city: city) do |g|
      g.name = "#{city} Guild"
    end
  end
end
