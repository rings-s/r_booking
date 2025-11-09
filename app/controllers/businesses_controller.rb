class BusinessesController < ApplicationController
  before_action :authenticate_user!, except: [:index, :show]
  before_action :check_owner_subscription, only: %i[ new create ]
  before_action :set_business, only: %i[ show edit update destroy calendar ]
  before_action :authorize_business_owner, only: %i[ edit update destroy calendar ]

  # GET /businesses or /businesses.json
  def index
    @businesses = Business.all
    @categories = Category.all
  end

  # GET /businesses/1 or /businesses/1.json
  def show
  end

  # GET /businesses/1/calendar
  def calendar
    @date = params[:date] ? Date.parse(params[:date]) : Date.today
    @bookings = Booking.joins(service: :business)
                       .where(businesses: { id: @business.id })
                       .where('DATE(start_time) = ?', @date)
                       .includes(:user, :service)
                       .order(:start_time)
  end

  # GET /businesses/new
  def new
    @business = Business.new
    @categories = Category.all
  end

  # GET /businesses/1/edit
  def edit
    @categories = Category.all
  end

  # POST /businesses or /businesses.json
  def create
    @business = Business.new(business_params)

    respond_to do |format|
      if @business.save
        format.html { redirect_to @business, notice: "Business was successfully created." }
        format.json { render :show, status: :created, location: @business }
      else
        @categories = Category.all
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @business.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /businesses/1 or /businesses/1.json
  def update
    respond_to do |format|
      if @business.update(business_params)
        format.html { redirect_to @business, notice: "Business was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @business }
      else
        @categories = Category.all
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @business.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /businesses/1 or /businesses/1.json
  def destroy
    @business.destroy!

    respond_to do |format|
      format.html { redirect_to businesses_path, notice: "Business was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_business
      @business = Business.find(params[:id])
    end

    # Ensure only the business owner or admin can modify the business
    def authorize_business_owner
      unless current_user == @business.user || current_user.admin?
        redirect_to businesses_path, alert: "You are not authorized to perform this action."
      end
    end

    # Check if owner has active subscription before creating business
    def check_owner_subscription
      return unless current_user.owner?

      # Try to create trial subscription if eligible
      unless current_user.subscribed?
        trial_sub = current_user.get_or_create_trial_subscription

        if trial_sub
          # Trial created successfully, allow to continue
          flash[:notice] = t('subscriptions.trial_started')
        else
          # No trial available, need to subscribe
          flash[:alert] = t('subscriptions.subscription_required')
          redirect_to new_subscription_path
        end
      end
    end

    # Only allow a list of trusted parameters through.
    def business_params
      params.require(:business).permit(:user_id, :name, :description, :location, :phone_number, :open_time, :close_time, :category_id, :logo, images: [])
    end
end
