class BookingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_service, only: [:new, :create, :available_slots]
  before_action :set_booking, only: [:show, :edit, :update, :destroy, :cancel]

  def index
    @bookings = current_user.client? ? current_user.bookings.includes(:service) : Booking.joins(service: :business).where(businesses: { user_id: current_user.id }).includes(:service, :user)
    @upcoming_bookings = @bookings.upcoming
    @past_bookings = @bookings.past
  end

  def show
    @can_cancel = @booking.user == current_user && @booking.start_time > 24.hours.from_now
  end

  def available_slots
    @date = params[:date] ? Date.parse(params[:date]) : Date.today
    @available_slots = @service.available_slots_for_date(@date)

    respond_to do |format|
      format.html
      format.json { render json: { slots: @available_slots, date: @date } }
    end
  end

  def new
    @booking = @service.bookings.build
    @date = params[:date] ? Date.parse(params[:date]) : Date.today
    @available_slots = @service.available_slots_for_date(@date)
  end

  def create
    @booking = @service.bookings.build(booking_params)
    @booking.user = current_user
    @booking.status = :pending

    if @booking.save
      redirect_to booking_path(@booking), notice: 'Booking successfully created! Check your email for confirmation.'
    else
      @date = @booking.start_time&.to_date || Date.today
      @available_slots = @service.available_slots_for_date(@date)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize_booking_owner!
  end

  def update
    authorize_booking_owner!

    if @booking.update(booking_params)
      redirect_to @booking, notice: 'Booking was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def cancel
    authorize_booking_owner!

    if @booking.start_time > 24.hours.from_now
      @booking.update(status: :cancelled)
      redirect_to bookings_path, notice: 'Booking was successfully cancelled.'
    else
      redirect_to @booking, alert: 'Cannot cancel booking less than 24 hours before start time.'
    end
  end

  def destroy
    authorize_booking_owner!
    @booking.destroy
    redirect_to bookings_path, notice: 'Booking was successfully deleted.'
  end

  private

  def set_service
    @service = Service.find(params[:service_id])
    @business = @service.business
  end

  def set_booking
    @booking = Booking.find(params[:id])
  end

  def authorize_booking_owner!
    unless @booking.user == current_user || @booking.service.business.user == current_user
      redirect_to bookings_path, alert: 'You are not authorized to perform this action.'
    end
  end

  def booking_params
    params.require(:booking).permit(:start_time, :notes)
  end
end
