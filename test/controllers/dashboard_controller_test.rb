require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "should get client" do
    get dashboard_client_url
    assert_response :success
  end

  test "should get owner" do
    get dashboard_owner_url
    assert_response :success
  end

  test "should get admin" do
    get dashboard_admin_url
    assert_response :success
  end
end
