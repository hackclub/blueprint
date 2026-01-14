class TeamController < ApplicationController
  allow_unauthenticated_access only: :index

  TEAM_JSON_PATH = Rails.root.join("config", "team.json")

  def index
    @team_members = load_team_members
  end

  private

  def load_team_members
    json = File.read(TEAM_JSON_PATH)
    JSON.parse(json)
  rescue Errno::ENOENT, JSON::ParserError => e
    Rails.logger.error("Error loading team.json: #{e.class}: #{e.message}")
    []
  end
end
