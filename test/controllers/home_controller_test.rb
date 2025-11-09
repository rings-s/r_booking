require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "should get profile" do
    get home_profile_url
    assert_response :success
  end
end
