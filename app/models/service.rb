class Service < ApplicationRecord
  belongs_to :business

  # Active Storage attachments
  has_many_attached :images

  validates :name, presence: true, uniqueness: { scope: :business_id }
  validates :duration, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }

  has_many :bookings, dependent: :destroy

  scope :by_business, ->(business_id) { where(business_id: business_id) }

  # Delegate category to business
  delegate :category, to: :business

  def formatted_price
    "$#{price.round(2)}"
  end

  def formatted_duration
    hours = duration / 60
    minutes = duration % 60

    if hours > 0 && minutes > 0
      "#{hours}h #{minutes}m"
    elsif hours > 0
      "#{hours}h"
    else
      "#{minutes}m"
    end
  end

  # Get available time slots for a given date
  def available_slots_for_date(date)
    return [] unless business.open_time && business.close_time

    slots = []
    current_time = Time.zone.parse("#{date} #{business.open_time.strftime('%H:%M:%S')}")
    end_of_day = Time.zone.parse("#{date} #{business.close_time.strftime('%H:%M:%S')}")

    # Get all bookings for this date
    booked_times = bookings.where('DATE(start_time) = ?', date)
                           .where.not(status: :cancelled)
                           .pluck(:start_time, :end_time)

    while current_time + duration.minutes <= end_of_day
      slot_end = current_time + duration.minutes

      # Check if this slot conflicts with any booking
      is_available = booked_times.none? do |booked_start, booked_end|
        (current_time < booked_end && slot_end > booked_start)
      end

      if is_available && current_time > Time.current
        slots << {
          start_time: current_time,
          end_time: slot_end,
          formatted: "#{current_time.strftime('%I:%M %p')} - #{slot_end.strftime('%I:%M %p')}"
        }
      end

      current_time += 30.minutes # 30-minute increments
    end

    slots
  end
end
