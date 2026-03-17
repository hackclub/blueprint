require "test_helper"

class GuildsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get guilds_url
    assert_response :success
    assert_select "h1", "Build Guilds!"
    assert_select "h2", "Information for Organizers"
    assert_select "h2", /Sign Up/
    assert_match /approved Blueprint project/, response.body
  end

  test "map_data returns json" do
    get guilds_map_data_url, as: :json
    assert_response :success
    data = JSON.parse(response.body)
    assert_kind_of Array, data
  end
end
