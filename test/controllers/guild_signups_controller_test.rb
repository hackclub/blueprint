require "test_helper"

class GuildSignupsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get guild_signups_new_url
    assert_response :success
  end

  test "should get create" do
    get guild_signups_create_url
    assert_response :success
  end
end
