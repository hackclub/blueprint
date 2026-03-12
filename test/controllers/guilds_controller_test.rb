require "test_helper"

class GuildsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get guilds_url
    assert_response :success
    assert_select "h1", "Guilds"
    assert_select "h2", "About the Program"
    assert_select "h2", "Information for Organizers"
    assert_select "h2", "Sign Up"
    assert_match /Hardware satellite meetups/, response.body
    assert_match /Mystic Tavern/, response.body
    assert_match /week beginning 6th April/, response.body
    assert_match /approved Blueprint project/, response.body
  end

  test "index shows existing guilds" do
    user = users(:one)
    user.update!(is_pro: true)
    guild = guilds(:one)

    get guilds_url, headers: { "rack.session" => { user_id: user.id } }
    assert_response :success
    assert_select ".text-xl", text: guild.name
  end

  test "non-pro users are prompted to enable expert mode" do
    open_session do |sess|
      sess.get guilds_url
      assert_response :success
      assert_match /Expert Mode/, sess.response.body
    end
  end
end
