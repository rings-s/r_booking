import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="admin-sidebar"
// Handles collapsible admin sidebar with state persistence and collapse functionality
export default class extends Controller {
  static targets = ["sidebar", "overlay", "text", "collapseBtn", "content"]

  connect() {
    // Restore sidebar states from localStorage
    const sidebarOpen = localStorage.getItem('adminSidebarOpen')
    const sidebarCollapsed = localStorage.getItem('adminSidebarCollapsed')

    // On desktop, restore collapsed state
    if (window.innerWidth >= 1024) {
      if (sidebarCollapsed === 'true') {
        this.collapse(false) // Don't animate on initial load
      }
    }

    // On mobile, respect open/close state (default closed)
    if (window.innerWidth < 1024) {
      if (sidebarOpen === 'true') {
        this.open()
      }
    }
  }

  // Mobile toggle (show/hide sidebar)
  toggle() {
    if (this.isOpen()) {
      this.close()
    } else {
      this.open()
    }
  }

  // Desktop collapse (icon-only mode)
  toggleCollapse() {
    if (this.isCollapsed()) {
      this.expand()
    } else {
      this.collapse()
    }
  }

  collapse(animate = true) {
    this.sidebarTarget.classList.add('sidebar-collapsed')
    this.sidebarTarget.classList.remove('w-64')
    this.sidebarTarget.classList.add('w-20')

    // Hide all text elements
    this.textTargets.forEach(text => {
      text.style.opacity = '0'
      setTimeout(() => {
        text.style.display = 'none'
      }, animate ? 150 : 0)
    })

    // Rotate collapse button icon
    if (this.hasCollapseBtnTarget) {
      const svg = this.collapseBtnTarget.querySelector('svg')
      svg.style.transform = 'rotate(180deg)'
    }

    // Adjust main content margin
    if (this.hasContentTarget) {
      this.contentTarget.classList.remove('lg:ml-64')
      this.contentTarget.classList.add('lg:ml-20')
    }

    this.saveCollapsedState(true)
  }

  expand(animate = true) {
    this.sidebarTarget.classList.remove('sidebar-collapsed')
    this.sidebarTarget.classList.remove('w-20')
    this.sidebarTarget.classList.add('w-64')

    // Show all text elements
    this.textTargets.forEach(text => {
      text.style.display = 'block'
      setTimeout(() => {
        text.style.opacity = '1'
      }, animate ? 50 : 0)
    })

    // Rotate collapse button icon back
    if (this.hasCollapseBtnTarget) {
      const svg = this.collapseBtnTarget.querySelector('svg')
      svg.style.transform = 'rotate(0deg)'
    }

    // Adjust main content margin
    if (this.hasContentTarget) {
      this.contentTarget.classList.remove('lg:ml-20')
      this.contentTarget.classList.add('lg:ml-64')
    }

    this.saveCollapsedState(false)
  }

  // Mobile open/close methods
  open() {
    this.sidebarTarget.classList.remove('-translate-x-full')
    this.sidebarTarget.classList.add('translate-x-0')

    // Show overlay on mobile
    if (window.innerWidth < 1024 && this.hasOverlayTarget) {
      this.overlayTarget.classList.remove('hidden')
    }

    this.saveMobileState(true)
  }

  close() {
    this.sidebarTarget.classList.add('-translate-x-full')
    this.sidebarTarget.classList.remove('translate-x-0')

    // Hide overlay
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.add('hidden')
    }

    this.saveMobileState(false)
  }

  // State checks
  isOpen() {
    return !this.sidebarTarget.classList.contains('-translate-x-full')
  }

  isCollapsed() {
    return this.sidebarTarget.classList.contains('sidebar-collapsed')
  }

  // State persistence
  saveMobileState(isOpen) {
    localStorage.setItem('adminSidebarOpen', isOpen.toString())
  }

  saveCollapsedState(isCollapsed) {
    localStorage.setItem('adminSidebarCollapsed', isCollapsed.toString())
  }

  disconnect() {
    // Clean up
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.add('hidden')
    }
  }
}
