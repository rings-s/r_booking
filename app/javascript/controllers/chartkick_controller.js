import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="chartkick"
// Rails 8 + Chartkick recommended Stimulus controller
export default class extends Controller {
  connect() {
    // Use requestAnimationFrame for better performance
    requestAnimationFrame(() => {
      this.initializeCharts()
    })
  }

  initializeCharts() {
    if (typeof window.Chartkick !== "undefined") {
      // Ensure all charts on the page are created (Chartkick auto-detects helpers' output)
      if (typeof window.Chartkick.createAll === 'function') {
        try { window.Chartkick.createAll() } catch (_) {}
      }
    }
  }

  // Method to refresh charts (useful for dynamic updates)
  refresh() {
    if (typeof window.Chartkick !== "undefined" && typeof window.Chartkick.createAll === 'function') {
      try { window.Chartkick.createAll() } catch (_) {}
    }
  }

  disconnect() {
    // Chartkick handles cleanup automatically in modern versions
    // No manual cleanup needed with proper Turbo integration
  }
}
