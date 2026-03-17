require "test_helper"

class SlackCommandsControllerTest < ActionDispatch::IntegrationTest
  test "should get guild_stats" do
    get slack_commands_guild_stats_url
    assert_response :success
  end
end
