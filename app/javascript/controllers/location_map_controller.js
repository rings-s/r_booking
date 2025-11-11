import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="location-map"
export default class extends Controller {
  static targets = ["latitude", "longitude", "address"]
  static values = {
    latitude: Number,
    longitude: Number
  }

  connect() {
    console.log('LocationMap controller connected!')

    // Wait for Leaflet to be loaded
    if (typeof L === 'undefined') {
      console.error('Leaflet is not loaded yet')
      setTimeout(() => this.connect(), 100)
      return
    }

    console.log('Leaflet loaded, initializing map...')

    // Use requestAnimationFrame for better timing
    requestAnimationFrame(() => {
      this.initializeMap()
    })
  }

  initializeMap() {
    // Default location: Riyadh, Saudi Arabia
    let lat = 24.7136
    let lng = 46.6753

    // Check if we have existing coordinates
    if (this.latitudeValue && this.longitudeValue) {
      lat = this.latitudeValue
      lng = this.longitudeValue
      console.log('Using existing coordinates:', lat, lng)
    } else {
      console.log('Using default coordinates (Riyadh):', lat, lng)
    }

    // Initialize the map
    console.log('Creating map instance...')
    this.map = L.map('map').setView([lat, lng], 13)

    // Add OpenStreetMap tile layer
    L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '&copy; <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a>'
    }).addTo(this.map)

    console.log('Map tiles added')

    // Force map to recalculate size
    setTimeout(() => {
      this.map.invalidateSize()
      console.log('Map size invalidated')
    }, 200)

    // Initialize marker
    this.marker = null

    // If there are existing coordinates, show them
    if (this.latitudeValue && this.longitudeValue) {
      this.setMarker(this.latitudeValue, this.longitudeValue)
    } else {
      // Auto-detect location for new businesses
      this.detectLocation()
    }

    // Allow clicking on map to set location
    this.map.on('click', (e) => {
      this.setMarker(e.latlng.lat, e.latlng.lng)
      this.updateAddressFromCoords(e.latlng.lat, e.latlng.lng)
    })
  }

  disconnect() {
    if (this.map) {
      this.map.remove()
    }
  }

  // Detect user's current location
  detectLocation() {
    if (!("geolocation" in navigator)) {
      console.warn('Geolocation not supported')
      return
    }

    navigator.geolocation.getCurrentPosition(
      (position) => {
        const lat = position.coords.latitude
        const lng = position.coords.longitude

        this.map.setView([lat, lng], 15)
        this.setMarker(lat, lng)
        this.updateAddressFromCoords(lat, lng)
      },
      (error) => {
        console.warn('Geolocation error:', error)
      },
      { enableHighAccuracy: true, timeout: 10000, maximumAge: 0 }
    )
  }

  // Set marker on map
  setMarker(lat, lng) {
    if (this.marker) {
      this.map.removeLayer(this.marker)
    }

    this.marker = L.marker([lat, lng], { draggable: true }).addTo(this.map)

    // Update when marker is dragged
    this.marker.on('dragend', (e) => {
      const position = e.target.getLatLng()
      this.updateFields(position.lat, position.lng)
      this.updateAddressFromCoords(position.lat, position.lng)
    })

    this.updateFields(lat, lng)
    this.marker.bindPopup(`Lat: ${lat.toFixed(6)}<br>Lng: ${lng.toFixed(6)}`).openPopup()
  }

  // Update form fields
  updateFields(lat, lng) {
    if (this.hasLatitudeTarget) {
      this.latitudeTarget.value = lat.toFixed(6)
    }
    if (this.hasLongitudeTarget) {
      this.longitudeTarget.value = lng.toFixed(6)
    }
  }

  // Reverse geocoding
  async updateAddressFromCoords(lat, lng) {
    if (!this.hasAddressTarget) return

    try {
      const response = await fetch(
        `https://nominatim.openstreetmap.org/reverse?format=json&lat=${lat}&lon=${lng}&zoom=18&addressdetails=1`
      )

      if (response.ok) {
        const data = await response.json()
        this.addressTarget.value = data.display_name || `${lat.toFixed(6)}, ${lng.toFixed(6)}`
      }
    } catch (error) {
      console.warn('Could not fetch address:', error)
    }
  }

  // Manual re-detect button
  redetect() {
    this.detectLocation()
  }
}
