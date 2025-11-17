import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="business-map"
// Read-only map display for business show page
export default class extends Controller {
  static values = {
    latitude: Number,
    longitude: Number,
    name: String
  }

  initialize() {
    this.map = null
    this.marker = null
  }

  connect() {
    console.log("BusinessMap controller connected!")

    // Listen for Turbo cache event
    this.boundBeforeCache = this.teardown.bind(this)
    document.addEventListener("turbo:before-cache", this.boundBeforeCache)

    this.waitForLeaflet()
  }

  waitForLeaflet() {
    if (typeof L === "undefined") {
      console.log("Waiting for Leaflet to load...")
      this.leafletRetries = (this.leafletRetries || 0) + 1

      if (this.leafletRetries > 100) {
        console.error("Leaflet failed to load after 5 seconds")
        return
      }

      this.leafletTimer = setTimeout(() => this.waitForLeaflet(), 50)
      return
    }

    console.log("Leaflet loaded, version:", L.version)
    this.leafletRetries = 0

    requestAnimationFrame(() => {
      this.initializeMap()
    })
  }

  initializeMap() {
    // Check if container already has a Leaflet instance (Turbo cache issue)
    if (this.element._leaflet_id) {
      console.log("Cleaning stale Leaflet instance from cached page...")
      delete this.element._leaflet_id
      this.element.innerHTML = ""
    }

    const lat = this.latitudeValue
    const lng = this.longitudeValue
    const name = this.nameValue || "Business Location"

    if (!lat || !lng) {
      console.error("Missing coordinates for business map")
      return
    }

    console.log("Creating business map at:", lat, lng)

    // Initialize map
    this.map = L.map(this.element).setView([lat, lng], 15)

    // Add OpenStreetMap tiles
    L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 19,
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
    }).addTo(this.map)

    // Add marker
    this.marker = L.marker([lat, lng]).addTo(this.map)
    this.marker.bindPopup(`<strong>${name}</strong><br>Lat: ${lat.toFixed(6)}<br>Lng: ${lng.toFixed(6)}`).openPopup()

    // Force size recalculation
    this.sizeTimer = setTimeout(() => {
      if (this.map) {
        this.map.invalidateSize()
        console.log("Business map size recalculated")
      }
    }, 100)

    console.log("Business map initialization complete")
  }

  teardown() {
    console.log("Turbo caching page - tearing down business map")
    this.destroyMap()
  }

  destroyMap() {
    if (this.leafletTimer) {
      clearTimeout(this.leafletTimer)
      this.leafletTimer = null
    }
    if (this.sizeTimer) {
      clearTimeout(this.sizeTimer)
      this.sizeTimer = null
    }

    if (this.map) {
      this.map.off()
      this.map.remove()
      this.map = null
      console.log("Business map instance destroyed")
    }

    if (this.element._leaflet_id) {
      delete this.element._leaflet_id
    }
    this.element.innerHTML = ""
    this.marker = null
  }

  disconnect() {
    console.log("BusinessMap controller disconnecting")

    if (this.boundBeforeCache) {
      document.removeEventListener("turbo:before-cache", this.boundBeforeCache)
      this.boundBeforeCache = null
    }

    this.destroyMap()
  }
}
