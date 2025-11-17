class GeocodingController < ApplicationController
  # Proxy endpoint for Nominatim geocoding
  # Needed because Nominatim blocks CORS requests from browsers

  def reverse
    lat = params[:lat]
    lng = params[:lng]

    unless lat.present? && lng.present?
      render json: { error: "Missing coordinates" }, status: :bad_request
      return
    end

    begin
      # Use Faraday to make the request with proper User-Agent
      response = Faraday.get("https://nominatim.openstreetmap.org/reverse") do |req|
        req.params = {
          format: "json",
          lat: lat,
          lon: lng,
          zoom: 18,
          addressdetails: 1
        }
        req.headers["User-Agent"] = "r_booking/1.0 (booking application)"
        req.headers["Accept"] = "application/json"
        req.options.timeout = 10
      end

      if response.success?
        data = JSON.parse(response.body)
        render json: {
          display_name: data["display_name"],
          address: data["address"]
        }
      else
        render json: { error: "Geocoding service error", status: response.status }, status: :service_unavailable
      end
    rescue Faraday::Error => e
      Rails.logger.error("Geocoding error: #{e.message}")
      render json: { error: "Geocoding service unavailable" }, status: :service_unavailable
    rescue JSON::ParserError => e
      Rails.logger.error("Geocoding JSON parse error: #{e.message}")
      render json: { error: "Invalid response from geocoding service" }, status: :internal_server_error
    end
  end

  # Forward geocoding - search for address and return coordinates
  def search
    query = params[:q]

    unless query.present?
      render json: { error: "Missing search query" }, status: :bad_request
      return
    end

    begin
      response = Faraday.get("https://nominatim.openstreetmap.org/search") do |req|
        req.params = {
          format: "json",
          q: query,
          limit: 5,
          addressdetails: 1
        }
        req.headers["User-Agent"] = "r_booking/1.0 (booking application)"
        req.headers["Accept"] = "application/json"
        req.options.timeout = 10
      end

      if response.success?
        data = JSON.parse(response.body)
        results = data.map do |place|
          {
            display_name: place["display_name"],
            lat: place["lat"].to_f,
            lon: place["lon"].to_f,
            address: place["address"]
          }
        end
        render json: { results: results }
      else
        render json: { error: "Geocoding service error", status: response.status }, status: :service_unavailable
      end
    rescue Faraday::Error => e
      Rails.logger.error("Geocoding search error: #{e.message}")
      render json: { error: "Geocoding service unavailable" }, status: :service_unavailable
    rescue JSON::ParserError => e
      Rails.logger.error("Geocoding JSON parse error: #{e.message}")
      render json: { error: "Invalid response from geocoding service" }, status: :internal_server_error
    end
  end
end
