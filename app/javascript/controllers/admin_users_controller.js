import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="admin-users"
// Handles user management interactions
export default class extends Controller {
  connect() {
    console.log("Admin users controller connected")
  }

  confirmDelete(event) {
    // Additional confirmation beyond Turbo's data-turbo-confirm
    const userName = event.target.closest('tr').querySelector('.text-sm.font-medium').textContent.trim()

    if (!confirm(`Are you absolutely sure you want to delete ${userName}? This action cannot be undone.`)) {
      event.preventDefault()
      event.stopPropagation()
    }
  }

  // Handle successful deletion with Turbo Stream
  handleDeleteSuccess(event) {
    const [data, status, xhr] = event.detail
    if (status === 200) {
      // Show success message
      this.showNotification('User deleted successfully', 'success')
    }
  }

  // Show notification
  showNotification(message, type = 'info') {
    const notification = document.createElement('div')
    notification.className = `fixed top-20 right-4 px-6 py-4 rounded-lg shadow-lg z-50 ${
      type === 'success' ? 'bg-gray-900 text-white' : 'bg-gray-100 text-gray-900'
    }`
    notification.textContent = message

    document.body.appendChild(notification)

    setTimeout(() => {
      notification.remove()
    }, 3000)
  }
}
