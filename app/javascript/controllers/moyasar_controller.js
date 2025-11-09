import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="moyasar"
// Implements Moyasar Payment Form integration following official documentation
// https://docs.moyasar.com/guides/card-payments/basic-integration/
export default class extends Controller {
  static values = {
    amount: Number,
    currency: String,
    description: String,
    publishableKey: String,
    callbackUrl: String,
    metadata: Object
  }

  connect() {
    // Validate Moyasar library is loaded
    if (typeof window.Moyasar === 'undefined') {
      console.error('Moyasar library not loaded. Ensure CDN script is included.')
      this.showError('Payment system not available. Please refresh the page.')
      return
    }

    // Validate minimum amount (Moyasar requires minimum 100 in smallest currency unit)
    if (this.amountValue < 100) {
      console.error(`Amount ${this.amountValue} is below Moyasar minimum of 100`)
      this.showError('Payment amount is invalid.')
      return
    }

    this.initializeMoyasar()
  }

  initializeMoyasar() {
    try {
      window.Moyasar.init({
        element: '.mysr-form',
        amount: this.amountValue,
        currency: this.currencyValue,
        description: this.descriptionValue,
        publishable_api_key: this.publishableKeyValue,
        callback_url: this.callbackUrlValue,
        supported_networks: ['visa', 'mastercard', 'mada'],
        methods: ['creditcard'],
        // Official Moyasar callback pattern: async function that saves payment
        on_completed: async (payment) => {
          await this.handlePaymentComplete(payment)
        },
        // Include metadata for tracking subscription details
        metadata: this.hasMetadataValue ? this.metadataValue : {}
      })
    } catch (error) {
      console.error('Moyasar initialization failed:', error)
      this.showError('Failed to initialize payment form. Please refresh the page.')
    }
  }

  async handlePaymentComplete(payment) {
    console.log('Payment completed:', payment.id)

    try {
      // Save payment to backend for server-side verification
      const response = await this.savePaymentToBackend(payment)

      if (response.success) {
        console.log('Payment verified and saved successfully')
        // Allow Moyasar to redirect to callback_url with payment ID
        // The callback_url will handle subscription activation
      } else {
        throw new Error(response.error || 'Payment verification failed')
      }
    } catch (error) {
      console.error('Payment processing error:', error)
      this.showError('Payment processing failed. Please contact support with payment ID: ' + payment.id)
      throw error
    }
  }

  async savePaymentToBackend(payment) {
    try {
      const response = await fetch('/subscriptions/verify_payment', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.getCSRFToken()
        },
        body: JSON.stringify({
          payment_id: payment.id,
          status: payment.status,
          amount: payment.amount,
          currency: payment.currency
        })
      })

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`)
      }

      return await response.json()
    } catch (error) {
      console.error('Backend save failed:', error)
      return { success: false, error: error.message }
    }
  }

  getCSRFToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.content : ''
  }

  showError(message) {
    // Display user-friendly error message
    const errorContainer = document.querySelector('.payment-error-message')
    if (errorContainer) {
      errorContainer.textContent = message
      errorContainer.classList.remove('hidden')
    } else {
      alert(message)
    }
  }

  disconnect() {
    console.log('Moyasar controller disconnected')
  }
}
