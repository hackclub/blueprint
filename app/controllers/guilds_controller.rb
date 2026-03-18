class GuildsController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :index, :map_data ]

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
        signup_count: g.guild_signups.size,
        slack_channel_id: g.slack_channel_id
      }
    }
  end
end
