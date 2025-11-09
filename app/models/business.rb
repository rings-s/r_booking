class Business < ApplicationRecord
  belongs_to :user
  belongs_to :category
  has_many :services, dependent: :destroy

  # Active Storage attachments
  has_one_attached :logo
  has_many_attached :images

  validates :name, presence: true
  validates :user, presence: true
  validates :category, presence: true
  validates :phone_number, format: { with: /\A[\d\s\-\+\(\)]+\z/, message: "must be a valid phone number" }, allow_blank: true

  # Only owners and admins can be associated with businesses
  validate :user_must_be_owner_or_admin

  # Check if business is currently open
  def currently_open?
    return false unless open_time && close_time

    current_time = Time.current
    current_minutes = current_time.hour * 60 + current_time.min
    open_minutes = open_time.hour * 60 + open_time.min
    close_minutes = close_time.hour * 60 + close_time.min

    current_minutes >= open_minutes && current_minutes < close_minutes
  end

  # Get time until opening/closing
  def time_until_status_change
    return nil unless open_time && close_time

    current_time = Time.current
    current_minutes = current_time.hour * 60 + current_time.min
    open_minutes = open_time.hour * 60 + open_time.min
    close_minutes = close_time.hour * 60 + close_time.min

    if currently_open?
      # Time until closing
      minutes_until = close_minutes - current_minutes
      format_time_until(minutes_until)
    else
      # Time until opening
      minutes_until = if current_minutes < open_minutes
        open_minutes - current_minutes
      else
        # Opens tomorrow
        (24 * 60) - current_minutes + open_minutes
      end
      format_time_until(minutes_until)
    end
  end

  private

  def user_must_be_owner_or_admin
    errors.add(:user, 'must be an owner or admin') if user && !user.owner? && !user.admin?
  end

  def format_time_until(minutes)
    hours = minutes / 60
    mins = minutes % 60

    if hours > 0 && mins > 0
      "#{hours}h #{mins}m"
    elsif hours > 0
      "#{hours}h"
    else
      "#{mins}m"
    end
  end
end
