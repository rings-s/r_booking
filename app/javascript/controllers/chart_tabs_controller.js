import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="chart-tabs"
// Handles tab switching for dashboard charts
export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = {
    active: { type: String, default: "users" }
  }

  connect() {
    this.showActiveTab()
  }

  switch(event) {
    event.preventDefault()
    const tab = event.currentTarget
    const targetPanel = tab.dataset.chartTabsTarget || tab.dataset.tab

    // Update active value
    this.activeValue = targetPanel

    // Update UI
    this.showActiveTab()

    // Ensure charts render correctly when a hidden tab becomes visible
    requestAnimationFrame(() => {
      // Trigger resize event for chart responsiveness
      window.dispatchEvent(new Event('resize'))

      // Ensure charts exist and then redraw inside the newly visible panel
      if (window.Chartkick) {
        // Create any charts that haven't been initialized yet
        if (typeof window.Chartkick.createAll === 'function') {
          try { window.Chartkick.createAll() } catch (e) { /* noop */ }
        }

        const activePanel = this.element.querySelector(`[data-panel="${this.activeValue}"]`)
        if (activePanel) {
          // Find Chartkick containers by their generated id prefix
          const chartDivs = activePanel.querySelectorAll("div[id^='chart-']")
          chartDivs.forEach(div => {
            const id = div.getAttribute('id')
            const chart = window.Chartkick.charts[id]
            if (chart) {
              if (typeof chart.redraw === 'function') {
                try { chart.redraw() } catch (e) { /* noop */ }
              } else if (typeof chart.refresh === 'function') {
                try { chart.refresh() } catch (e) { /* noop */ }
              }
            }
          })
        }
      }
    })
  }

  showActiveTab() {
    // Update tab styles
    this.tabTargets.forEach(tab => {
      const tabName = tab.dataset.tab

      if (tabName === this.activeValue) {
        // Active tab styling
        tab.classList.remove('text-gray-600', 'border-transparent')
        tab.classList.add('text-gray-900', 'border-gray-900')
      } else {
        // Inactive tab styling
        tab.classList.remove('text-gray-900', 'border-gray-900')
        tab.classList.add('text-gray-600', 'border-transparent')
      }
    })

    // Show/hide panels
    this.panelTargets.forEach(panel => {
      const panelName = panel.dataset.panel

      if (panelName === this.activeValue) {
        panel.classList.remove('hidden')
      } else {
        panel.classList.add('hidden')
      }
    })
  }
}
