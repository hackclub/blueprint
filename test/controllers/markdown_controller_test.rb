require "test_helper"

class MarkdownControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get guides_show_url
    assert_response :success
  end
end
