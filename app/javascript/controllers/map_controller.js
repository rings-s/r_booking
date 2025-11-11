import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="map"
export default class extends Controller {
  static values = {
    latitude: Number,
    longitude: Number,
    businessName: String
  }

  connect() {
    const lat = this.latitudeValue || 24.7136;
    const lng = this.longitudeValue || 46.6753;

    const map = L.map(this.element).setView([lat, lng], 13);

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
    }).addTo(map);

    if (this.latitudeValue && this.longitudeValue) {
      const marker = L.marker([this.latitudeValue, this.longitudeValue]).addTo(map);
      marker.bindPopup(this.businessNameValue).openPopup();
    }
  }
}
