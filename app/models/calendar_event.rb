class CalendarEvent < ApplicationRecord
  belongs_to :business
  belongs_to :booking

  validates :title, :start_time, :end_time, presence: true
  validate :end_time_after_start_time

  scope :for_date, ->(date) { where('DATE(start_time) = ?', date) }
  scope :upcoming, -> { where('start_time > ?', Time.current).order(:start_time) }
  scope :between, ->(start_date, end_date) { where(start_time: start_date..end_date).order(:start_time) }

  def duration_minutes
    ((end_time - start_time) / 60).to_i
  end

  private

  def end_time_after_start_time
    return if end_time.blank? || start_time.blank?

    if end_time <= start_time
      errors.add(:end_time, 'must be after start time')
    end
  end
end
