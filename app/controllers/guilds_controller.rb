class GuildsController < ApplicationController
  # currently anyone can hit this URL but the UI will hide/disable the link
  # for users who aren't in expert/pro mode.  We still fetch the list of guilds
  # so the view can render them when the feature ships.
  def index
    @guilds = Guild.order(:name)
  end
end
