import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="navbar"
export default class extends Controller {
  static targets = ["mobileMenu", "userMenu", "mobileMenuButton", "userMenuButton"]

  connect() {
    // Close menus when clicking outside
    this.boundCloseOnOutsideClick = this.closeOnOutsideClick.bind(this)
    document.addEventListener('click', this.boundCloseOnOutsideClick)
  }

  disconnect() {
    document.removeEventListener('click', this.boundCloseOnOutsideClick)
  }

  // Toggle mobile menu
  toggleMobileMenu(event) {
    event.stopPropagation()
    this.mobileMenuTarget.classList.toggle('hidden')

    // Animate hamburger icon
    const icon = this.mobileMenuButtonTarget
    icon.classList.toggle('open')
  }

  // Toggle user dropdown menu
  toggleUserMenu(event) {
    event.stopPropagation()
    this.userMenuTarget.classList.toggle('hidden')
    this.userMenuTarget.classList.toggle('opacity-0')
    this.userMenuTarget.classList.toggle('scale-95')
  }

  // Close menus when clicking outside
  closeOnOutsideClick(event) {
    const clickedOutsideMobile = this.hasMobileMenuTarget &&
                                  !this.mobileMenuTarget.contains(event.target) &&
                                  !this.mobileMenuButtonTarget.contains(event.target)

    const clickedOutsideUser = this.hasUserMenuTarget &&
                                !this.userMenuTarget.contains(event.target) &&
                                !this.userMenuButtonTarget.contains(event.target)

    if (clickedOutsideMobile && !this.mobileMenuTarget.classList.contains('hidden')) {
      this.mobileMenuTarget.classList.add('hidden')
      this.mobileMenuButtonTarget.classList.remove('open')
    }

    if (clickedOutsideUser && !this.userMenuTarget.classList.contains('hidden')) {
      this.userMenuTarget.classList.add('hidden', 'opacity-0', 'scale-95')
    }
  }

  // Close mobile menu (for when clicking a link)
  closeMobileMenu() {
    if (this.hasMobileMenuTarget) {
      this.mobileMenuTarget.classList.add('hidden')
      this.mobileMenuButtonTarget.classList.remove('open')
    }
  }
}
