module Admin
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_admin
    layout 'admin'

    private

    def authorize_admin
      unless current_user.admin?
        redirect_to root_path, alert: 'Access denied. Admin privileges required.'
      end
    end
  end
end
