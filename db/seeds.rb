# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Create sample categories
puts 'Creating categories...'
categories = {
  hair: Category.find_or_create_by!(name: 'Hair Salon', description: 'Professional hair care services'),
  auto: Category.find_or_create_by!(name: 'Auto Repair', description: 'Vehicle maintenance and repair'),
  health: Category.find_or_create_by!(name: 'Healthcare', description: 'Medical and wellness services'),
  consulting: Category.find_or_create_by!(name: 'Consulting', description: 'Professional consulting services')
}

# Create an owner user
puts 'Creating owner user...'
owner = User.find_or_create_by!(email: 'owner@example.com') do |u|
  u.password = 'password123'
  u.password_confirmation = 'password123'
  u.role = :owner
  u.name = 'John Owner'
end

# Create trial subscription for owner
puts 'Creating trial subscription for owner...'
unless owner.current_subscription
  owner.subscriptions.create!(
    status: :trial,
    amount: 99.00,
    currency: 'SAR',
    trial_ends_at: 2.weeks.from_now,
    current_period_start: Time.current,
    current_period_end: 2.weeks.from_now
  )
end

# Create a business
puts 'Creating business...'
business = Business.find_or_create_by!(name: 'Best Services LLC', user: owner) do |b|
  b.description = 'Quality services for everyone'
  b.location = '123 Main St'
  b.category = categories[:hair]
  b.open_time = Time.zone.parse('09:00')
  b.close_time = Time.zone.parse('18:00')
end

# Update existing business with hours and category if needed
if business.open_time.nil? || business.category.nil?
  business.update(
    category: categories[:hair],
    open_time: Time.zone.parse('09:00'),
    close_time: Time.zone.parse('18:00')
  )
end

# Create sample services (category is now on the business, not individual services)
puts 'Creating services...'
services_data = [
  { name: 'Haircut', duration: 30, price: 25.00, description: 'Professional haircut service' },
  { name: 'Hair Color', duration: 90, price: 75.00, description: 'Full hair coloring treatment' },
  { name: 'Scalp Treatment', duration: 45, price: 40.00, description: 'Therapeutic scalp massage and treatment' },
  { name: 'Blow Dry', duration: 30, price: 30.00, description: 'Professional blow dry styling' },
  { name: 'Hair Extensions', duration: 120, price: 200.00, description: 'Premium hair extension application' }
]

services_data.each do |data|
  Service.find_or_create_by!(name: data[:name], business: business) do |s|
    s.duration = data[:duration]
    s.price = data[:price]
    s.description = data[:description]
  end
end

# Create a client user
puts 'Creating client user...'
client = User.find_or_create_by!(email: 'client@example.com') do |u|
  u.password = 'password123'
  u.password_confirmation = 'password123'
  u.role = :client
  u.name = 'Jane Client'
end

# Create an admin user
puts 'Creating admin user...'
admin = User.find_or_create_by!(email: 'admin@email.com') do |u|
  u.password = 'admin123'
  u.password_confirmation = 'admin123'
  u.role = :admin
  u.name = 'Admin User'
end

# Create additional users for chart data (spread across last 6 months)
puts 'Creating historical users for chart data...'
dates_for_users = [
  6.months.ago, 5.months.ago, 4.months.ago, 3.months.ago, 2.months.ago, 1.month.ago, 3.weeks.ago, 2.weeks.ago, 1.week.ago
]

dates_for_users.each_with_index do |date, index|
  2.times do |i|
    User.find_or_create_by!(email: "user#{index}_#{i}@example.com") do |u|
      u.password = 'password123'
      u.password_confirmation = 'password123'
      u.role = :client
      u.name = "User #{index} #{i}"
      u.created_at = date
      u.updated_at = date
    end
  end
end

# Create additional businesses for chart data
puts 'Creating historical businesses for chart data...'
dates_for_businesses = [
  5.months.ago, 4.months.ago, 3.months.ago, 2.months.ago, 3.weeks.ago, 1.week.ago
]

dates_for_businesses.each_with_index do |date, index|
  # Create owner for each business
  business_owner = User.find_or_create_by!(email: "business_owner#{index}@example.com") do |u|
    u.password = 'password123'
    u.password_confirmation = 'password123'
    u.role = :owner
    u.name = "Business Owner #{index}"
    u.created_at = date
    u.updated_at = date
  end

  # Create trial subscription
  unless business_owner.current_subscription
    business_owner.subscriptions.create!(
      status: :trial,
      amount: 99.00,
      currency: 'SAR',
      trial_ends_at: date + 2.weeks,
      current_period_start: date,
      current_period_end: date + 2.weeks,
      created_at: date,
      updated_at: date
    )
  end

  # Create business
  Business.find_or_create_by!(name: "Business #{index}", user: business_owner) do |b|
    b.description = "Sample business #{index}"
    b.location = "Location #{index}"
    b.category = categories.values.sample
    b.open_time = Time.zone.parse('09:00')
    b.close_time = Time.zone.parse('18:00')
    b.created_at = date
    b.updated_at = date
  end
end

# Create sample bookings with historical data
puts 'Creating sample bookings with historical data...'
haircut_service = Service.find_by(name: 'Haircut')
color_service = Service.find_by(name: 'Hair Color')
all_services = Service.all
all_clients = User.where(role: :client)

if haircut_service && all_clients.any?
  # Create bookings across the last 6 months
  dates_for_bookings = [
    6.months.ago, 5.months.ago, 4.months.ago, 3.months.ago, 2.months.ago, 1.month.ago, 3.weeks.ago, 2.weeks.ago, 1.week.ago, Date.tomorrow, Date.today + 7.days
  ]

  dates_for_bookings.each_with_index do |date, index|
    next if date > Time.current # Skip future dates for historical bookings
    
    # Create 1-3 bookings per time period
    rand(1..3).times do |i|
      service = all_services.sample
      client = all_clients.sample
      
      booking_time = if date.future?
        Time.zone.parse("#{date.to_date} 10:00") + (i * 2).hours
      else
        date + (10 + i * 2).hours
      end

      # Create unique booking by including more specific attributes
      booking = Booking.find_or_initialize_by(
        user: client,
        service: service,
        start_time: booking_time
      )
      
      unless booking.persisted?
        booking.status = date.future? ? :confirmed : [:confirmed, :completed, :cancelled].sample
        booking.notes = "Booking #{index}_#{i}"
        booking.created_at = date.future? ? Time.current : date
        booking.updated_at = date.future? ? Time.current : date
        
        begin
          booking.save!
        rescue ActiveRecord::RecordInvalid => e
          puts "Skipping duplicate booking: #{e.message}"
        end
      end
    end
  end

  puts "Created #{Booking.count} bookings"
end

# Note: Most time slots remain available for booking
puts "Available slots: Business is open 9 AM - 6 PM daily"
puts "Only 2 slots are pre-booked to leave plenty of availability for testing"

puts ''
puts '✅ Seed data created successfully!'
puts ''
puts 'Login credentials:'
puts "Owner - Email: owner@example.com | Password: password123 (with 2-week trial)"
puts "Client - Email: client@example.com | Password: password123"
puts "Admin - Email: admin@example.com | Password: admin123"
puts ''
puts "Business: #{business.name}"
puts "Business Hours: #{business.open_time.strftime('%I:%M %p')} - #{business.close_time.strftime('%I:%M %p')}"
puts "Categories: #{Category.count}"
puts "Services: #{Service.count}"
puts "Bookings: #{Booking.count}"
puts "Subscriptions: #{Subscription.count}"
puts "Calendar Events: #{CalendarEvent.count}"
