json.extract! calendar_event, :id, :business_id, :title, :start_time, :end_time, :booking_id, :created_at, :updated_at
json.url calendar_event_url(calendar_event, format: :json)
