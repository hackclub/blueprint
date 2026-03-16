require "test_helper"

class GuildSignupsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get new_guild_signup_url
    assert_response :success
  end

  test "create requires authentication" do
    post guild_signups_url, params: { guild_signup: { role: "attendee", name: "Test", email: "test@test.com", city: "London", country: "gb" } }
    assert_response :redirect
  end
end
