module Admin
  class UsersController < Admin::BaseController
    before_action :set_user, only: [:show, :edit, :update, :destroy]

    def index
      @users = User.order(created_at: :desc)

      # Search functionality
      if params[:search].present?
        @users = @users.where("name LIKE ? OR email LIKE ?", "%#{params[:search]}%", "%#{params[:search]}%")
      end

      # Filter by role
      if params[:role].present? && params[:role] != 'all'
        @users = @users.where(role: params[:role])
      end

      # Limit results to avoid performance issues
      @users = @users.limit(100)
    end

    def show
    end

    def new
      @user = User.new
    end

    def create
      @user = User.new(user_params)

      if @user.save
        respond_to do |format|
          format.html { redirect_to admin_users_path, notice: 'User created successfully.' }
          format.turbo_stream
        end
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      # Handle password update - skip validation if blank
      update_params = user_params

      if update_params[:password].blank?
        update_params = update_params.except(:password, :password_confirmation)
      end

      if @user.update(update_params)
        respond_to do |format|
          format.html { redirect_to admin_users_path, notice: 'User updated successfully.' }
          format.turbo_stream
        end
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      # Prevent admin from deleting themselves
      if @user == current_user
        redirect_to admin_users_path, alert: 'You cannot delete your own account.'
        return
      end

      @user.destroy

      respond_to do |format|
        format.html { redirect_to admin_users_path, notice: 'User deleted successfully.' }
        format.turbo_stream
      end
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.require(:user).permit(:name, :email, :role, :password, :password_confirmation)
    end
  end
end
