import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  connect() {
    // Close dropdown when clicking outside
    this.outsideClickHandler = this.handleOutsideClick.bind(this)
  }

  toggle(event) {
    event.stopPropagation()
    this.menuTarget.classList.toggle("hidden")

    if (!this.menuTarget.classList.contains("hidden")) {
      // Use setTimeout to avoid immediate closure
      setTimeout(() => {
        document.addEventListener("click", this.outsideClickHandler)
      }, 10)
    } else {
      document.removeEventListener("click", this.outsideClickHandler)
    }
  }

  handleOutsideClick(event) {
    // Don't interfere with link clicks - let them complete naturally
    if (!this.element.contains(event.target)) {
      this.closeDropdown()
    }
  }

  // Method to close dropdown
  closeDropdown() {
    this.menuTarget.classList.add("hidden")
    document.removeEventListener("click", this.outsideClickHandler)
  }

  disconnect() {
    document.removeEventListener("click", this.outsideClickHandler)
  }
}
