class DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_client, only: [:client]
  before_action :authorize_owner, only: [:owner]
  before_action :authorize_admin, only: [:admin]

  # Index - Route to appropriate dashboard based on user role
  def index
    if current_user.admin?
      redirect_to dashboard_admin_path
    elsif current_user.owner?
      redirect_to dashboard_owner_path
    elsif current_user.client?
      redirect_to dashboard_client_path
    else
      redirect_to root_path, alert: "Please sign in to access the dashboard."
    end
  end

  # Client Dashboard
  def client
    @user = current_user
    @bookings = current_user.bookings
                            .includes(service: :business)
                            .order(start_time: :desc)

    # Upcoming bookings
    @upcoming_bookings = @bookings.where('start_time >= ?', Time.current)
                                  .where(status: [:pending, :confirmed])
                                  .limit(5)

    # Past bookings
    @past_bookings = @bookings.where('start_time < ?', Time.current)
                              .limit(5)

    # Bookings by status
    @bookings_by_status = @bookings.group(:status).count

    # Bookings by month (last 6 months)
    @bookings_by_month = @bookings.where('start_time >= ?', 6.months.ago)
                                   .group_by_month(:start_time, format: "%b %Y")
                                   .count
  end

  # Owner Dashboard
  def owner
    @user = current_user
    @businesses = current_user.businesses.includes(:services)

    # Get all bookings for owner's businesses
    @all_bookings = Booking.joins(service: :business)
                           .where(businesses: { user_id: current_user.id })
                           .includes(:user, service: :business)

    # Revenue statistics
    @total_revenue = @all_bookings.where(status: :completed)
                                  .joins(:service)
                                  .sum(:price)

    @monthly_revenue = @all_bookings.where(status: :completed, start_time: 1.month.ago..Time.current)
                                    .joins(:service)
                                    .sum(:price)

    # Booking statistics
    @total_bookings = @all_bookings.count
    @pending_bookings = @all_bookings.where(status: :pending).count
    @confirmed_bookings = @all_bookings.where(status: :confirmed).count
    @completed_bookings = @all_bookings.where(status: :completed).count

    # Today's bookings
    @todays_bookings = @all_bookings.where('DATE(start_time) = ?', Date.today)
                                    .order(:start_time)

    # Upcoming bookings (next 7 days)
    @upcoming_bookings = @all_bookings.where(start_time: Time.current..(Time.current + 7.days))
                                      .where(status: [:pending, :confirmed])
                                      .order(:start_time)
                                      .limit(10)

    # Charts data
    # Revenue by month (last 12 months)
    @revenue_by_month = @all_bookings.where(status: :completed, start_time: 12.months.ago..Time.current)
                                     .group_by_month(:start_time, format: "%b %Y")
                                     .joins(:service)
                                     .sum(:price)

    # Bookings by status
    @bookings_by_status = @all_bookings.group(:status).count

    # Bookings by day (last 30 days)
    @bookings_by_day = @all_bookings.where(start_time: 30.days.ago..Time.current)
                                    .group_by_day(:start_time, format: "%b %d")
                                    .count

    # Top services by bookings
    @top_services = Service.joins(:bookings)
                           .where(business_id: @businesses.pluck(:id))
                           .group('services.name')
                           .count
                           .sort_by { |_k, v| -v }
                           .first(5)
                           .to_h

    # Revenue by service
    @revenue_by_service = Service.joins(:bookings)
                                 .where(business_id: @businesses.pluck(:id), bookings: { status: :completed })
                                 .group('services.name')
                                 .sum(:price)
                                 .sort_by { |_k, v| -v }
                                 .first(5)
                                 .to_h
  end

  # Admin Dashboard
  def admin
    @user = current_user

    # Overall statistics
    @total_users = User.count
    @total_owners = User.where(role: :owner).count
    @total_clients = User.where(role: :client).count
    @total_businesses = Business.count
    @total_services = Service.count
    @total_bookings = Booking.count
    @total_categories = Category.count

    # Revenue statistics
    @total_revenue = Booking.where(status: :completed)
                            .joins(:service)
                            .sum(:price)

    @monthly_revenue = Booking.where(status: :completed, start_time: 1.month.ago..Time.current)
                              .joins(:service)
                              .sum(:price)

    # Recent activity
    @recent_users = User.order(created_at: :desc).limit(5)
    @recent_businesses = Business.includes(:user).order(created_at: :desc).limit(5)
    @recent_bookings = Booking.includes(:user, service: :business)
                              .order(created_at: :desc)
                              .limit(10)

    # Charts data
    # Users by role
    @users_by_role = User.group(:role).count

    # Users by month (last 12 months)
    @users_by_month = User.where(created_at: 12.months.ago..Time.current)
                          .group_by_month(:created_at, format: "%b %Y")
                          .count

    # Businesses by month (last 12 months)
    @businesses_by_month = Business.where(created_at: 12.months.ago..Time.current)
                                   .group_by_month(:created_at, format: "%b %Y")
                                   .count

    # Bookings by month (last 12 months)
    @bookings_by_month = Booking.where(start_time: 12.months.ago..Time.current)
                                .group_by_month(:start_time, format: "%b %Y")
                                .count

    # Bookings by status
    @bookings_by_status = Booking.group(:status).count

    # Revenue by month (last 12 months)
    @revenue_by_month = Booking.where(status: :completed, start_time: 12.months.ago..Time.current)
                               .group_by_month(:start_time, format: "%b %Y")
                               .joins(:service)
                               .sum(:price)

    # Top businesses by bookings
    @top_businesses = Business.joins(services: :bookings)
                              .group('businesses.name')
                              .count
                              .sort_by { |_k, v| -v }
                              .first(5)
                              .to_h

    # Top categories by businesses
    @businesses_by_category = Business.joins(:category)
                                      .group('categories.name')
                                      .count
  end

  private

  def authorize_client
    unless current_user.client? || current_user.admin?
      redirect_to root_path, alert: "Access denied. This dashboard is for clients only."
    end
  end

  def authorize_owner
    unless current_user.owner? || current_user.admin?
      redirect_to root_path, alert: "Access denied. This dashboard is for business owners only."
    end
  end

  def authorize_admin
    unless current_user.admin?
      redirect_to root_path, alert: "Access denied. This dashboard is for administrators only."
    end
  end
end
