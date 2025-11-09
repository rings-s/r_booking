class Booking < ApplicationRecord
  belongs_to :user
  belongs_to :service
  has_one :calendar_event, dependent: :destroy
  has_one :business, through: :service

  enum :status, { pending: 0, confirmed: 1, cancelled: 2, completed: 3 }

  validates :start_time, presence: true
  validate :end_time_after_start_time
  validate :no_time_conflict
  validate :within_business_hours

  before_validation :set_end_time_from_duration, on: :create
  before_create :generate_qr_code
  after_create :create_calendar_event_for_owner

  scope :upcoming, -> { where('start_time > ?', Time.current).order(:start_time) }
  scope :past, -> { where('start_time <= ?', Time.current).order(start_time: :desc) }
  scope :by_status, ->(status) { where(status: status) }

  def duration_minutes
    service.duration
  end

  def formatted_time_range
    "#{start_time.strftime('%b %d, %Y at %I:%M %p')} - #{end_time.strftime('%I:%M %p')}"
  end

  private

  def end_time_after_start_time
    return if end_time.blank? || start_time.blank?

    if end_time <= start_time
      errors.add(:end_time, 'must be after start time')
    end
  end

  def no_time_conflict
    return if start_time.blank? || end_time.blank?

    conflicting_bookings = service.bookings
                                  .where.not(id: id)
                                  .where.not(status: :cancelled)
                                  .where('(start_time < ? AND end_time > ?) OR (start_time < ? AND end_time > ?)',
                                         end_time, start_time, start_time, end_time)

    if conflicting_bookings.exists?
      errors.add(:start_time, 'conflicts with an existing booking')
    end
  end

  def within_business_hours
    return if start_time.blank? || service.blank?

    business = service.business
    return if business.open_time.blank? || business.close_time.blank?

    # Extract hour and minute components for comparison
    booking_start_hour = start_time.hour
    booking_start_min = start_time.min
    booking_end_hour = end_time.hour
    booking_end_min = end_time.min

    open_hour = business.open_time.hour
    open_min = business.open_time.min
    close_hour = business.close_time.hour
    close_min = business.close_time.min

    booking_start_minutes = booking_start_hour * 60 + booking_start_min
    booking_end_minutes = booking_end_hour * 60 + booking_end_min
    open_minutes = open_hour * 60 + open_min
    close_minutes = close_hour * 60 + close_min

    if booking_start_minutes < open_minutes || booking_end_minutes > close_minutes
      errors.add(:start_time, "must be within business hours (#{business.open_time.strftime('%I:%M %p')} - #{business.close_time.strftime('%I:%M %p')})")
    end
  end

  def set_end_time_from_duration
    self.end_time = start_time + duration_minutes.minutes if start_time && !end_time
  end

  def generate_qr_code
    require 'rqrcode'
    require 'chunky_png'

    # Generate unique QR code data with booking information
    qr_data = {
      booking_id: id,
      user_id: user_id,
      service_id: service_id,
      business_id: service.business_id,
      start_time: start_time.to_i,
      verification_code: SecureRandom.hex(8)
    }.to_json

    qrcode = RQRCode::QRCode.new(qr_data, level: :h)

    # Generate PNG QR code
    png = qrcode.as_png(
      bit_depth: 1,
      border_modules: 4,
      color_mode: ChunkyPNG::COLOR_GRAYSCALE,
      color: 'black',
      fill: 'white',
      module_px_size: 6,
      size: 300
    )

    # Save PNG to public/qr_codes directory
    qr_codes_dir = Rails.root.join('public', 'qr_codes')
    FileUtils.mkdir_p(qr_codes_dir) unless Dir.exist?(qr_codes_dir)

    filename = "booking_#{id}_#{SecureRandom.hex(4)}.png"
    filepath = qr_codes_dir.join(filename)

    IO.binwrite(filepath, png.to_s)

    # Store the path in qr_code field
    self.qr_code = "/qr_codes/#{filename}"

    Rails.logger.info("QR code generated for booking #{id}: #{self.qr_code}")
  rescue => e
    Rails.logger.error("Failed to generate QR code: #{e.message}")
    # Fallback to SVG if PNG fails
    begin
      qrcode = RQRCode::QRCode.new(qr_data)
      self.qr_code = qrcode.as_svg(module_size: 6)
    rescue
      Rails.logger.error("Fallback SVG generation also failed")
    end
  end

  def create_calendar_event_for_owner
    CalendarEvent.create!(
      business: service.business,
      booking: self,
      title: "#{service.name} - #{user.name || user.email}",
      start_time: start_time,
      end_time: end_time
    )
  rescue => e
    Rails.logger.error("Failed to create calendar event: #{e.message}")
  end
end
