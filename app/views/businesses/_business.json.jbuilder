json.extract! business, :id, :user_id, :name, :description, :location, :open_time, :close_time, :created_at, :updated_at
json.url business_url(business, format: :json)
