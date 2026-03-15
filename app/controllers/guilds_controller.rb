class GuildsController < ApplicationController
  def index
    @guilds = Guild.order(:name)
    @signup = GuildSignup.new
  end

  def map_data
    @guilds = Guild.includes(:guild_signups).all
    render json: @guilds.map { |g|
      {
        id: g.id,
        name: g.name,
        city: g.city,
        lat: g.latitude,
        lng: g.longitude,
        signup_count: g.guild_signups.count
      }
    }
  end
end
