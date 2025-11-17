class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  # CSRF protection is handled by omniauth-rails_csrf_protection gem
  # The callback receives requests from Google's servers (external), not user's browser

  def google_oauth2
    auth = request.env["omniauth.auth"]
    @user = User.find_existing_oauth_user(auth)

    if @user&.persisted?
      # Existing user - sign them in
      flash[:notice] = I18n.t "devise.omniauth_callbacks.success", kind: "Google"
      sign_in_and_redirect @user, event: :authentication
    else
      # New user - redirect to role selection
      session["devise.google_data"] = auth.except("extra").to_h
      redirect_to new_users_oauth_role_selection_path
    end
  end

  def failure
    redirect_to root_path
  end
end
