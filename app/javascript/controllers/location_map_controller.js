import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="location-map"
export default class extends Controller {
  static targets = ["map", "latitude", "longitude", "address", "search", "searchResults"]
  static values = {
    latitude: Number,
    longitude: Number
  }

  initialize() {
    // Called once when controller is first instantiated
    this.map = null
    this.marker = null
  }

  connect() {
    console.log("LocationMap controller connected!")

    // Listen for Turbo cache event - CRITICAL for third-party libraries
    this.boundBeforeCache = this.teardown.bind(this)
    document.addEventListener("turbo:before-cache", this.boundBeforeCache)

    // Also listen for Turbo render to handle morphing
    this.boundAfterRender = this.handleTurboRender.bind(this)
    document.addEventListener("turbo:render", this.boundAfterRender)

    // Wait for Leaflet to be available (loaded via script tag)
    this.waitForLeaflet()
  }

  handleTurboRender() {
    // Re-initialize map if it was destroyed during Turbo morphing
    if (!this.map && this.hasMapTarget) {
      console.log("Re-initializing map after Turbo render")
      this.waitForLeaflet()
    }
  }

  waitForLeaflet() {
    if (typeof L === "undefined") {
      console.log("Waiting for Leaflet to load...")
      this.leafletRetries = (this.leafletRetries || 0) + 1

      // Give up after 100 retries (5 seconds)
      if (this.leafletRetries > 100) {
        console.error("Leaflet failed to load after 5 seconds")
        return
      }

      this.leafletTimer = setTimeout(() => this.waitForLeaflet(), 50)
      return
    }

    console.log("Leaflet loaded, version:", L.version)
    this.leafletRetries = 0

    // Ensure map target exists and has dimensions
    if (!this.hasMapTarget) {
      console.error("Map target not found in DOM")
      return
    }

    const rect = this.mapTarget.getBoundingClientRect()
    console.log("Map container dimensions:", rect.width, "x", rect.height)

    // Use requestAnimationFrame to ensure DOM is fully ready
    requestAnimationFrame(() => {
      this.initializeMap()
    })
  }

  initializeMap() {
    if (!this.hasMapTarget) {
      console.error("Map target not found")
      return
    }

    // IMPORTANT: Check if container already has Leaflet instance
    // This happens when Turbo restores a cached page
    if (this.mapTarget._leaflet_id) {
      console.log("Cleaning stale Leaflet instance from cached page...")
      delete this.mapTarget._leaflet_id
      this.mapTarget.innerHTML = ""
    }

    // Default to Riyadh, Saudi Arabia
    let lat = 24.7136
    let lng = 46.6753

    if (this.hasLatitudeValue && this.hasLongitudeValue && this.latitudeValue && this.longitudeValue) {
      lat = this.latitudeValue
      lng = this.longitudeValue
      console.log("Using existing coordinates:", lat, lng)
    } else {
      console.log("Using default coordinates (Riyadh)")
    }

    // Initialize map
    console.log("Creating map instance...")
    this.map = L.map(this.mapTarget).setView([lat, lng], 13)

    // Add OpenStreetMap tiles
    L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 19,
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
    }).addTo(this.map)

    // Force recalculate size after DOM settles
    this.sizeTimer = setTimeout(() => {
      if (this.map) {
        this.map.invalidateSize()
        console.log("Map size recalculated")
      }
    }, 100)

    // Set up marker and interactions
    this.marker = null

    if (this.hasLatitudeValue && this.hasLongitudeValue && this.latitudeValue && this.longitudeValue) {
      this.setMarker(lat, lng)
    }
    // Don't auto-detect location - let user click the "Detect My Location" button
    // or click on the map to set their location manually
    // This avoids incorrect location detection when using VPN

    // Click to set location
    this.map.on("click", (e) => {
      this.setMarker(e.latlng.lat, e.latlng.lng)
      this.reverseGeocode(e.latlng.lat, e.latlng.lng)
    })

    console.log("Map initialization complete")
    console.log("Click on the map or use 'Detect My Location' button to set your location")
  }

  // Called BEFORE Turbo caches the page - essential for cleanup
  teardown() {
    console.log("Turbo caching page - tearing down map")
    this.destroyMap()
  }

  destroyMap() {
    // Clear timers
    if (this.leafletTimer) {
      clearTimeout(this.leafletTimer)
      this.leafletTimer = null
    }
    if (this.sizeTimer) {
      clearTimeout(this.sizeTimer)
      this.sizeTimer = null
    }

    // Remove map instance properly
    if (this.map) {
      this.map.off() // Remove all event listeners
      this.map.remove() // Destroy map instance
      this.map = null
      console.log("Map instance destroyed")
    }

    // Clean container for fresh initialization
    if (this.hasMapTarget) {
      // Remove Leaflet's internal ID reference
      if (this.mapTarget._leaflet_id) {
        delete this.mapTarget._leaflet_id
      }
      // Clear any leftover DOM elements
      this.mapTarget.innerHTML = ""
    }

    this.marker = null
  }

  disconnect() {
    console.log("LocationMap controller disconnecting")

    // Remove Turbo event listeners
    if (this.boundBeforeCache) {
      document.removeEventListener("turbo:before-cache", this.boundBeforeCache)
      this.boundBeforeCache = null
    }

    if (this.boundAfterRender) {
      document.removeEventListener("turbo:render", this.boundAfterRender)
      this.boundAfterRender = null
    }

    this.destroyMap()
  }

  detectLocation() {
    if (!navigator.geolocation) {
      console.warn("Geolocation not supported")
      return
    }

    navigator.geolocation.getCurrentPosition(
      (position) => {
        const { latitude, longitude } = position.coords
        if (this.map) {
          this.map.setView([latitude, longitude], 15)
          this.setMarker(latitude, longitude)
          this.reverseGeocode(latitude, longitude)
        }
      },
      (error) => {
        console.warn("Geolocation error:", error.message)
      },
      { enableHighAccuracy: true, timeout: 10000, maximumAge: 0 }
    )
  }

  setMarker(lat, lng) {
    if (!this.map) return

    if (this.marker) {
      this.map.removeLayer(this.marker)
    }

    this.marker = L.marker([lat, lng], { draggable: true }).addTo(this.map)

    this.marker.on("dragend", (e) => {
      const pos = e.target.getLatLng()
      this.updateFormFields(pos.lat, pos.lng)
      this.reverseGeocode(pos.lat, pos.lng)
      this.marker.setPopupContent(`Lat: ${pos.lat.toFixed(6)}<br>Lng: ${pos.lng.toFixed(6)}`)
    })

    this.updateFormFields(lat, lng)
    this.marker.bindPopup(`Lat: ${lat.toFixed(6)}<br>Lng: ${lng.toFixed(6)}`).openPopup()
  }

  updateFormFields(lat, lng) {
    if (this.hasLatitudeTarget) {
      this.latitudeTarget.value = lat.toFixed(6)
    }
    if (this.hasLongitudeTarget) {
      this.longitudeTarget.value = lng.toFixed(6)
    }
  }

  async reverseGeocode(lat, lng) {
    if (!this.hasAddressTarget) return

    try {
      // Use our backend proxy to avoid CORS issues with Nominatim
      const response = await fetch(
        `/geocoding/reverse?lat=${lat}&lng=${lng}`,
        {
          headers: {
            "Accept": "application/json",
            "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
          }
        }
      )

      if (response.ok) {
        const data = await response.json()
        this.addressTarget.value = data.display_name || `${lat.toFixed(6)}, ${lng.toFixed(6)}`
      } else {
        console.warn("Reverse geocoding response not OK:", response.status)
        // Fallback to coordinates
        this.addressTarget.value = `${lat.toFixed(6)}, ${lng.toFixed(6)}`
      }
    } catch (error) {
      console.warn("Reverse geocoding failed:", error)
      // Fallback to coordinates on error
      if (this.hasAddressTarget) {
        this.addressTarget.value = `${lat.toFixed(6)}, ${lng.toFixed(6)}`
      }
    }
  }

  // Action method for re-detect button
  redetect() {
    this.detectLocation()
  }

  // Search for address
  async searchAddress(event) {
    event.preventDefault()
    if (!this.hasSearchTarget) return

    const query = this.searchTarget.value.trim()
    if (!query) return

    console.log("Searching for address:", query)

    try {
      const response = await fetch(
        `/geocoding/search?q=${encodeURIComponent(query)}`,
        {
          headers: {
            "Accept": "application/json",
            "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
          }
        }
      )

      if (response.ok) {
        const data = await response.json()
        this.showSearchResults(data.results || [])
      } else {
        console.warn("Address search failed:", response.status)
        this.showSearchResults([])
      }
    } catch (error) {
      console.warn("Address search error:", error)
      this.showSearchResults([])
    }
  }

  showSearchResults(results) {
    if (!this.hasSearchResultsTarget) return

    if (results.length === 0) {
      this.searchResultsTarget.innerHTML = '<div class="p-3 text-gray-500 text-sm">No results found</div>'
      this.searchResultsTarget.classList.remove("hidden")
      return
    }

    const html = results.map((result) => `
      <button type="button"
              class="w-full text-left px-3 py-2 hover:bg-blue-50 border-b border-gray-100 last:border-0 text-sm"
              data-action="click->location-map#selectSearchResult"
              data-lat="${result.lat}"
              data-lon="${result.lon}"
              data-address="${result.display_name.replace(/"/g, '&quot;')}">
        ${result.display_name}
      </button>
    `).join("")

    this.searchResultsTarget.innerHTML = html
    this.searchResultsTarget.classList.remove("hidden")
  }

  selectSearchResult(event) {
    event.preventDefault()
    const button = event.currentTarget
    const lat = parseFloat(button.dataset.lat)
    const lon = parseFloat(button.dataset.lon)
    const address = button.dataset.address

    console.log("Selected location:", lat, lon, address)

    // Center map on selected location
    if (this.map) {
      this.map.setView([lat, lon], 15)
      this.setMarker(lat, lon)
    }

    // Update address field
    if (this.hasAddressTarget) {
      this.addressTarget.value = address
    }

    // Clear search input and hide results
    if (this.hasSearchTarget) {
      this.searchTarget.value = ""
    }
    if (this.hasSearchResultsTarget) {
      this.searchResultsTarget.classList.add("hidden")
    }
  }

  // Hide search results when clicking outside
  hideSearchResults(event) {
    if (this.hasSearchResultsTarget && !this.searchResultsTarget.contains(event.target)) {
      this.searchResultsTarget.classList.add("hidden")
    }
  }
}
