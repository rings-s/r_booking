import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["searchInput", "filterPanel", "filterButton", "businessCard"]
  static values = {
    category: String
  }

  connect() {
    this.filterVisible = false
    console.log('Business filter controller connected')
    console.log('Found', this.businessCardTargets.length, 'business cards')
  }

  // Toggle filter panel visibility
  toggleFilters(event) {
    event.preventDefault()
    this.filterVisible = !this.filterVisible

    if (this.filterVisible) {
      this.filterPanelTarget.classList.remove("hidden")
      this.filterPanelTarget.classList.add("animate-fade-in")
    } else {
      this.filterPanelTarget.classList.add("hidden")
      this.filterPanelTarget.classList.remove("animate-fade-in")
    }
  }

  // Search functionality
  search() {
    const searchTerm = this.searchInputTarget.value.toLowerCase()
    console.log('Searching for:', searchTerm)

    let visibleCount = 0
    this.businessCardTargets.forEach(card => {
      const businessName = (card.dataset.businessName || "").toLowerCase()
      const businessDescription = (card.dataset.businessDescription || "").toLowerCase()

      const matches = businessName.includes(searchTerm) ||
                     businessDescription.includes(searchTerm)

      if (matches || searchTerm === "") {
        card.classList.remove("hidden")
        card.classList.add("animate-fade-in")
        visibleCount++
      } else {
        card.classList.add("hidden")
        card.classList.remove("animate-fade-in")
      }
    })

    console.log('Visible businesses:', visibleCount)
    this.updateEmptyState()
  }

  // Filter by category
  filterByCategory(event) {
    const categoryId = event.currentTarget.dataset.categoryId

    // Update active state on filter buttons
    this.element.querySelectorAll('[data-category-id]').forEach(btn => {
      btn.classList.remove("bg-gray-900", "text-white")
      btn.classList.add("bg-white", "text-gray-700", "hover:bg-gray-50")
    })

    event.currentTarget.classList.remove("bg-white", "text-gray-700", "hover:bg-gray-50")
    event.currentTarget.classList.add("bg-gray-900", "text-white")

    // Filter businesses
    this.businessCardTargets.forEach(card => {
      const businessCategory = card.dataset.businessCategory

      if (categoryId === "all" || businessCategory === categoryId) {
        card.classList.remove("hidden")
        card.classList.add("animate-fade-in")
      } else {
        card.classList.add("hidden")
        card.classList.remove("animate-fade-in")
      }
    })

    this.updateEmptyState()
  }

  // Clear all filters
  clearFilters() {
    this.searchInputTarget.value = ""

    // Reset category filter buttons
    this.element.querySelectorAll('[data-category-id]').forEach(btn => {
      btn.classList.remove("bg-gray-900", "text-white")
      btn.classList.add("bg-white", "text-gray-700", "hover:bg-gray-50")
    })

    // Set "All" as active
    const allButton = this.element.querySelector('[data-category-id="all"]')
    if (allButton) {
      allButton.classList.remove("bg-white", "text-gray-700", "hover:bg-gray-50")
      allButton.classList.add("bg-gray-900", "text-white")
    }

    // Show all businesses
    this.businessCardTargets.forEach(card => {
      card.classList.remove("hidden")
      card.classList.add("animate-fade-in")
    })

    this.updateEmptyState()
  }

  // Update empty state visibility
  updateEmptyState() {
    const visibleCards = this.businessCardTargets.filter(card =>
      !card.classList.contains("hidden")
    )

    const emptyState = this.element.querySelector("#empty-state")
    const businessGrid = this.element.querySelector("#business-grid")

    if (visibleCards.length === 0) {
      if (emptyState) emptyState.classList.remove("hidden")
      if (businessGrid) businessGrid.classList.add("hidden")
    } else {
      if (emptyState) emptyState.classList.add("hidden")
      if (businessGrid) businessGrid.classList.remove("hidden")
    }
  }
}
