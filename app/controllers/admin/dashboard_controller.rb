module Admin
  class DashboardController < Admin::BaseController
    def index
      # Summary statistics
      @total_users = User.count
      @new_users_this_month = User.where("created_at >= ?", Time.current.beginning_of_month).count
      @total_bookings = Booking.count
      @total_businesses = Business.count

      # === LINE CHART DATA: Registrations/Creations Over Time (Last 6 Months) ===
      @line_users = User.group_by_month(:created_at, last: 6).count
      @line_businesses = Business.group_by_month(:created_at, last: 6).count
      @line_bookings = Booking.group_by_month(:created_at, last: 6).count

      # === DOUGHNUT CHART DATA: Recent vs Older (Last 30 Days) ===
      recent_users = User.where("created_at >= ?", 30.days.ago).count
      older_users = User.where("created_at < ?", 30.days.ago).count

      recent_businesses = Business.where("created_at >= ?", 30.days.ago).count
      older_businesses = Business.where("created_at < ?", 30.days.ago).count

      recent_bookings = Booking.where("created_at >= ?", 30.days.ago).count
      older_bookings = Booking.where("created_at < ?", 30.days.ago).count

      @doughnut_users = {
        "Recent (Last 30 Days)" => recent_users,
        "Older" => older_users
      }

      @doughnut_businesses = {
        "Recent (Last 30 Days)" => recent_businesses,
        "Older" => older_businesses
      }

      @doughnut_bookings = {
        "Recent (Last 30 Days)" => recent_bookings,
        "Older" => older_bookings
      }

      # === BAR CHART DATA: Distribution ===
      @bar_users = User.group(:role).count.transform_keys { |k| k.titleize }

      # Business by category - handle empty case
      category_counts = {}
      Business.includes(:category).find_each do |business|
        category_name = business.category&.name || "Uncategorized"
        category_counts[category_name] ||= 0
        category_counts[category_name] += 1
      end
      # Add placeholder if empty
      @bar_businesses = category_counts.empty? ? { "No Businesses Yet" => 0 } : category_counts

      # Bookings by status
      booking_counts = Booking.group(:status).count.transform_keys { |k| k.titleize }
      @bar_bookings = booking_counts.empty? ? { "No Bookings Yet" => 0 } : booking_counts
    end
  end
end
