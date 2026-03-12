class GuildsController < ApplicationController
  def index
    @guilds = Guild.order(:name)
    @signup = GuildSignup.new
  end
end
