# frozen_string_literal: true

class Users::OauthRoleSelectionsController < ApplicationController
  before_action :redirect_if_signed_in
  before_action :ensure_oauth_data

  def new
    @user = User.new
  end

  def create
    oauth_data = session["devise.google_data"]

    @user = User.new(
      email: oauth_data["info"]["email"],
      password: Devise.friendly_token[0, 20],
      name: oauth_data["info"]["name"],
      avatar_url: oauth_data["info"]["image"],
      provider: oauth_data["provider"],
      uid: oauth_data["uid"],
      role: role_params[:role]
    )

    if @user.save
      session.delete("devise.google_data")
      flash[:notice] = I18n.t("devise.omniauth_callbacks.success", kind: "Google")
      sign_in_and_redirect @user, event: :authentication
    else
      flash.now[:alert] = @user.errors.full_messages.join("\n")
      render :new, status: :unprocessable_entity
    end
  end

  private

  def redirect_if_signed_in
    redirect_to root_path if user_signed_in?
  end

  def ensure_oauth_data
    unless session["devise.google_data"].present?
      redirect_to new_user_registration_path, alert: I18n.t("auth.oauth_role_selection.session_expired")
    end
  end

  def role_params
    params.require(:user).permit(:role)
  end
end
