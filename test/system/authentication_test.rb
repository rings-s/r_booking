require "application_system_test_case"

class AuthenticationTest < ApplicationSystemTestCase
  test "user can sign up as client" do
    visit new_user_registration_path

    assert_text "Create your account"

    fill_in "Name", with: "Test Client"
    fill_in "Email", with: "testclient@example.com"
    fill_in "Password", with: "password123"
    fill_in "Password confirmation", with: "password123"

    # Click the client role label (radio button is hidden)
    find("label[for='user_role_client']").click

    click_button "Create Account"

    assert_text "Welcome! You have signed up successfully"
  end

  test "user can sign up as owner" do
    visit new_user_registration_path

    assert_text "Create your account"

    fill_in "Name", with: "Test Owner"
    fill_in "Email", with: "testowner@example.com"
    fill_in "Password", with: "password123"
    fill_in "Password confirmation", with: "password123"

    # Click the owner role label (radio button is hidden)
    find("label[for='user_role_owner']").click

    click_button "Create Account"

    assert_text "Welcome! You have signed up successfully"
  end

  test "user can sign in" do
    # Use fixture user
    visit new_user_session_path

    assert_text "Welcome back"

    fill_in "Email", with: "client1@example.com"
    fill_in "Password", with: "password123"

    click_button "Sign in"

    assert_text "Signed in successfully"
  end

  test "user can sign out" do
    # Use fixture user and sign in
    visit new_user_session_path
    fill_in "Email", with: "client1@example.com"
    fill_in "Password", with: "password123"
    click_button "Sign in"

    # Open the user menu dropdown (desktop view)
    # Find the user menu button by looking for the user's name
    find("button", text: "Client One").click

    # Find the first Sign Out button (desktop menu) and click it
    # Use match: :first to handle the ambiguity between desktop and mobile menus
    click_button "Sign Out", match: :first

    assert_text "Signed out successfully"
  end
end
