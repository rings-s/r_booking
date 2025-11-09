json.extract! queue_ticket, :id, :booking_id, :position, :status, :issued_at, :created_at, :updated_at
json.url queue_ticket_url(queue_ticket, format: :json)
