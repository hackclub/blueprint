class GuildsController < ApplicationController
  before_action :authenticate_user!

  def index
    @guilds = Guild.order(:name)
    @signup = GuildSignup.new
  end

  def map_data
    @guilds = Guild.includes(:guild_signups)
                   .where.not(latitude: nil, longitude: nil)
                   .where(needs_review: [false, nil])
                   .where.not(status: :closed)
    render json: @guilds.map { |g|
      {
        id: g.id,
        name: g.name,
        city: g.city,
        country: g.country,
        lat: g.latitude,
        lng: g.longitude,
        signup_count: g.guild_signups.size
      }
    }
  end
end
