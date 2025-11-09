class ServicesController < ApplicationController
  before_action :authenticate_user!, except: [:index, :show]
  before_action :set_business
  before_action :set_service, only: [:show, :edit, :update, :destroy]
  before_action :authorize_owner!, except: [:index, :show]

  def index
    @services = @business.services
  end

  def show
  end

  def new
    @service = @business.services.build
  end

  def create
    @service = @business.services.build(service_params)

    if @service.save
      redirect_to business_service_path(@business, @service), notice: 'Service was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @service.update(service_params)
      redirect_to business_service_path(@business, @service), notice: 'Service was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @service.destroy
    redirect_to business_services_path(@business), notice: 'Service was successfully deleted.'
  end

  private

  def set_business
    @business = Business.find(params[:business_id])
  end

  def set_service
    @service = @business.services.find(params[:id])
  end

  def authorize_owner!
    unless current_user == @business.user
      redirect_to business_services_path(@business), alert: 'You are not authorized to perform this action.'
    end
  end

  def service_params
    params.require(:service).permit(:name, :description, :duration, :price, images: [])
  end
end
