json.extract! booking, :id, :user_id, :service_id, :start_time, :end_time, :status, :qr_code, :notes, :created_at, :updated_at
json.url booking_url(booking, format: :json)
