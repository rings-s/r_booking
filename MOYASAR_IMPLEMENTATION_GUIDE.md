# Moyasar Payment Gateway Implementation Guide - Complete Tutorial

This comprehensive guide teaches you how to implement the Moyasar payment gateway in a Rails application for accepting credit card payments. Moyasar is Saudi Arabia's leading payment gateway supporting Visa, Mastercard, and Mada.

---

## Table of Contents

1. [Understanding Payment Gateways](#understanding-payment-gateways)
2. [Moyasar Overview](#moyasar-overview)
3. [Prerequisites](#prerequisites)
4. [Implementation Architecture](#implementation-architecture)
5. [Step-by-Step Implementation](#step-by-step-implementation)
6. [Code Explanation](#code-explanation)
7. [Security Measures](#security-measures)
8. [Testing](#testing)
9. [Production Deployment](#production-deployment)
10. [Troubleshooting](#troubleshooting)

---

## Understanding Payment Gateways

### What is a Payment Gateway?

A payment gateway is a service that securely processes credit card payments between your application and banks. Think of it as a digital point-of-sale terminal.

### Why Use a Payment Gateway?

**Security**:
- You never handle raw card numbers (PCI compliance nightmare)
- Gateway handles encryption and secure transmission
- Reduces your liability

**Features**:
- Supports multiple payment methods (cards, wallets, bank transfers)
- Handles 3D Secure authentication
- Provides fraud detection
- Manages refunds and chargebacks

### PCI Compliance

**PCI DSS** (Payment Card Industry Data Security Standard) requires strict security measures if you handle card data.

**Solutions**:
1. **Hosted Payment Page**: User enters card on gateway's page (easiest, used by Moyasar)
2. **Embedded Form**: Gateway provides JS library to create secure form on your site
3. **API Integration**: You handle cards directly (requires PCI compliance certification)

We'll use **Embedded Form** approach for better UX while maintaining security.

---

## Moyasar Overview

### What is Moyasar?

Moyasar is a Saudi Arabia-based payment gateway supporting:
- **Credit Cards**: Visa, Mastercard
- **Mada**: Saudi Arabia's local payment network
- **Apple Pay**: Mobile payments (requires additional setup)
- **STC Pay**: Saudi Telecom's digital wallet

### Why Moyasar?

**For Saudi Market**:
- Supports SAR (Saudi Riyal) natively
- Integrated with Saudi banking system
- Mada support (required for Saudi businesses)
- Arabic interface support

**Developer-Friendly**:
- Clean REST API
- Good documentation
- Transparent pricing
- Test mode with test cards

### Moyasar Pricing

- **Transaction Fee**: ~2.5-2.9% + fixed fee per transaction
- **No Monthly Fees**: Pay only for transactions
- **No Setup Fee**: Free to start

Check latest pricing at: https://moyasar.com/pricing

---

## Prerequisites

### 1. Moyasar Account

1. Sign up at https://moyasar.com/
2. Complete KYC verification (business documents)
3. Get approved (usually 1-3 business days)

### 2. Required Gems

Add to your `Gemfile`:

```ruby
# HTTP client for API calls
gem 'faraday', '~> 2.7'
```

Run:
```bash
bundle install
```

**Why Faraday?** We'll use it for server-side API calls to Moyasar (you can also use `Net::HTTP` which is built-in).

### 3. Database Setup

You'll need models to track subscriptions and payments. Example:

```ruby
# app/models/subscription.rb
class Subscription < ApplicationRecord
  belongs_to :user

  enum :status, {
    trial: 0,
    active: 1,
    past_due: 2,
    cancelled: 3,
    expired: 4
  }
end
```

Migration:
```ruby
create_table :subscriptions do |t|
  t.references :user, null: false, foreign_key: true
  t.integer :status, default: 0, null: false
  t.decimal :amount, precision: 10, scale: 2
  t.string :currency, default: 'SAR'
  t.string :moyasar_payment_id
  t.datetime :trial_ends_at
  t.datetime :current_period_start
  t.datetime :current_period_end
  t.datetime :cancelled_at
  t.timestamps
end
```

---

## Implementation Architecture

### Payment Flow Diagram

```
User Visits Payment Page
         ↓
Moyasar.js Loads Payment Form
         ↓
User Enters Card Details (handled by Moyasar.js)
         ↓
User Submits Payment
         ↓
Moyasar Processes Payment (3D Secure if needed)
         ↓
on_completed callback fired
         ↓
AJAX Request to /subscriptions/verify_payment
         ↓
Server Fetches Payment from Moyasar API (GET /payments/:id)
         ↓
Server Verifies Payment (amount, status, currency)
         ↓
Return {success: true} to Client
         ↓
Moyasar Redirects to Callback URL
         ↓
GET /subscriptions/callback?id=payment_id
         ↓
Server Fetches & Verifies Payment Again
         ↓
Create Subscription Record
         ↓
Redirect to Success Page
```

### Security: Double Verification Pattern

**Why verify twice?**

1. **Client-side verification** (`verify_payment`):
   - Immediate feedback before redirect
   - Prevents showing errors after redirect
   - Can handle errors gracefully

2. **Server-side verification** (`callback`):
   - Ultimate source of truth
   - Protects against client-side tampering
   - Ensures subscription only created after confirmed payment

This **defense-in-depth** approach prevents fraud even if client-side verification is bypassed.

### Key Security Measures

1. **Never trust client**: Always verify payment server-side
2. **Verify amount**: Ensure user paid correct amount
3. **Prevent replay attacks**: Check payment not already used
4. **Use HTTPS**: Required in production
5. **Store payment ID**: Link subscription to Moyasar payment

---

## Step-by-Step Implementation

### Step 1: Get Moyasar API Keys

#### 1.1 Access Moyasar Dashboard

1. Log in to https://dashboard.moyasar.com/
2. Go to **Settings** → **API Keys**

#### 1.2 Copy Your Keys

You'll see two types:

**Test Mode** (for development):
- **Publishable Key**: `pk_test_xxxxxx` (safe to expose in frontend)
- **Secret Key**: `sk_test_xxxxxx` (KEEP SECURE, server-side only)

**Live Mode** (for production):
- **Publishable Key**: `pk_live_xxxxxx`
- **Secret Key**: `sk_live_xxxxxx`

**Important**: Secret keys have full API access - never expose them in JavaScript or HTML!

---

### Step 2: Store Credentials Securely

#### 2.1 Edit Rails Credentials

```bash
EDITOR=nano bin/rails credentials:edit
```

#### 2.2 Add Moyasar Keys

```yaml
# For development (use test keys)
moyasar_publishable_key: pk_test_YOUR_PUBLISHABLE_KEY
moyasar_secret_key: sk_test_YOUR_SECRET_KEY

# For production (uncomment and use live keys)
# moyasar_publishable_key: pk_live_YOUR_PUBLISHABLE_KEY
# moyasar_secret_key: sk_live_YOUR_SECRET_KEY
```

Save and close (Ctrl+X, Y, Enter).

**Why Rails credentials?**
- Encrypted (safe to commit to Git)
- Environment-specific (development/production can have different keys)
- Decrypted using `config/master.key` (don't commit this!)

---

### Step 3: Create Moyasar Configuration Module

Create file `config/initializers/moyasar.rb`:

```ruby
# Moyasar Payment Gateway Configuration
# API Documentation: https://docs.moyasar.com/

module Moyasar
  class << self
    # Get publishable key (safe to expose in frontend)
    def publishable_key
      key = Rails.application.credentials.moyasar_publishable_key

      # In development, provide helpful error if not configured
      if key.blank? && Rails.env.development?
        Rails.logger.warn "⚠️  Moyasar publishable key not configured"
        return "pk_test_PLEASE_CONFIGURE_YOUR_KEY"
      end

      key
    end

    # Get secret key (NEVER expose in frontend!)
    def secret_key
      key = Rails.application.credentials.moyasar_secret_key

      if key.blank? && Rails.env.development?
        Rails.logger.warn "⚠️  Moyasar secret key not configured"
        return "sk_test_PLEASE_CONFIGURE_YOUR_KEY"
      end

      key
    end

    # Moyasar API base URL
    def api_url
      'https://api.moyasar.com/v1'
    end

    # Monthly subscription price in SAR
    def monthly_subscription_amount
      99.00
    end

    # Convert SAR to halalas (smallest currency unit)
    # Moyasar requires amounts in halalas: 1 SAR = 100 halalas
    def to_halalas(amount_in_sar)
      (amount_in_sar * 100).to_i
    end

    # Convert halalas to SAR
    def to_sar(amount_in_halalas)
      (amount_in_halalas / 100.0).round(2)
    end
  end
end
```

**Key Points**:
- **Publishable key**: Can be used in frontend JavaScript
- **Secret key**: Server-side only, full API access
- **Halalas**: Moyasar uses smallest currency unit (like cents for USD)
- **Helper methods**: Encapsulate configuration in one place

**Test it**:
```bash
bin/rails console
Moyasar.publishable_key  # Should show your key
Moyasar.to_halalas(99.00)  # Should return 9900
```

---

### Step 4: Create Stimulus Controller (Frontend)

Create file `app/javascript/controllers/moyasar_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

// Implements Moyasar Payment Form
// Documentation: https://docs.moyasar.com/guides/card-payments/basic-integration/
export default class extends Controller {
  static values = {
    amount: Number,           // Amount in halalas
    currency: String,         // Currency code (SAR)
    description: String,      // Payment description
    publishableKey: String,   // Moyasar publishable key
    callbackUrl: String,      // Where to redirect after payment
    metadata: Object          // Additional data to track
  }

  connect() {
    // Validate Moyasar library is loaded from CDN
    if (typeof window.Moyasar === 'undefined') {
      console.error('Moyasar library not loaded')
      this.showError('Payment system unavailable. Please refresh.')
      return
    }

    // Validate amount (Moyasar requires minimum 100 halalas)
    if (this.amountValue < 100) {
      console.error(`Amount ${this.amountValue} below minimum of 100`)
      this.showError('Invalid payment amount.')
      return
    }

    this.initializeMoyasar()
  }

  initializeMoyasar() {
    try {
      window.Moyasar.init({
        // Element where Moyasar will render the form
        element: '.mysr-form',

        // Payment details
        amount: this.amountValue,
        currency: this.currencyValue,
        description: this.descriptionValue,

        // Your publishable API key
        publishable_api_key: this.publishableKeyValue,

        // Where Moyasar redirects after payment
        callback_url: this.callbackUrlValue,

        // Supported payment methods
        supported_networks: ['visa', 'mastercard', 'mada'],
        methods: ['creditcard'],

        // Callback when payment completes
        // CRITICAL: Verify payment on server before allowing redirect
        on_completed: async (payment) => {
          await this.handlePaymentComplete(payment)
        },

        // Additional data to include with payment
        metadata: this.hasMetadataValue ? this.metadataValue : {}
      })
    } catch (error) {
      console.error('Moyasar initialization failed:', error)
      this.showError('Failed to load payment form. Please refresh.')
    }
  }

  async handlePaymentComplete(payment) {
    console.log('Payment completed:', payment.id)

    try {
      // Save payment to backend for verification
      const response = await this.savePaymentToBackend(payment)

      if (response.success) {
        console.log('Payment verified successfully')
        // Moyasar will automatically redirect to callback_url
      } else {
        throw new Error(response.error || 'Payment verification failed')
      }
    } catch (error) {
      console.error('Payment processing error:', error)
      this.showError(
        `Payment processing failed. ` +
        `Please contact support with payment ID: ${payment.id}`
      )
      // Prevent redirect by throwing error
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
      console.error('Backend verification failed:', error)
      return { success: false, error: error.message }
    }
  }

  getCSRFToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.content : ''
  }

  showError(message) {
    // Display error to user
    const errorContainer = document.querySelector('.payment-error-message')
    if (errorContainer) {
      errorContainer.textContent = message
      errorContainer.classList.remove('hidden')
    } else {
      alert(message)  // Fallback
    }
  }
}
```

**Key Concepts**:

1. **Stimulus Values**: Data passed from HTML to JavaScript
2. **`on_completed` callback**: Fired when Moyasar completes payment
3. **Double verification**: Verify on server before allowing redirect
4. **Error handling**: Show user-friendly errors, prevent redirect on failure
5. **CSRF token**: Required for POST requests in Rails

---

### Step 5: Create Subscriptions Controller (Backend)

Create file `app/controllers/subscriptions_controller.rb`:

```ruby
class SubscriptionsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_owner_role, only: [:new, :create]
  before_action :set_subscription, only: [:show, :cancel]

  # GET /subscriptions/new
  # Show payment form
  def new
    # Check if already subscribed
    if current_user.subscribed?
      redirect_to subscription_path(current_user.current_subscription),
                  notice: 'You already have an active subscription'
      return
    end

    @subscription = Subscription.new(
      user: current_user,
      amount: Moyasar.monthly_subscription_amount,
      currency: 'SAR'
    )
  end

  # POST /subscriptions/verify_payment
  # Called by Stimulus controller to verify payment before redirect
  # SECURITY: First verification checkpoint
  def verify_payment
    payment_id = params[:payment_id]

    unless payment_id.present?
      render json: { success: false, error: 'Payment ID required' },
             status: :bad_request
      return
    end

    # Fetch payment from Moyasar API
    payment_details = fetch_moyasar_payment(payment_id)

    if payment_details[:success]
      payment = payment_details[:payment]

      # Verify payment details
      if verify_payment_details(payment)
        render json: {
          success: true,
          payment_id: payment['id'],
          status: payment['status']
        }
      else
        render json: {
          success: false,
          error: 'Payment verification failed'
        }, status: :unprocessable_entity
      end
    else
      render json: {
        success: false,
        error: payment_details[:error]
      }, status: :unprocessable_entity
    end
  end

  # GET /subscriptions/callback?id=payment_id
  # Moyasar redirects here after payment
  # SECURITY: Second verification checkpoint (ultimate source of truth)
  def callback
    payment_id = params[:id]

    unless payment_id.present?
      redirect_to new_subscription_path, alert: 'Invalid payment reference'
      return
    end

    # Fetch payment from Moyasar API
    payment_details = fetch_moyasar_payment(payment_id)

    unless payment_details[:success]
      redirect_to new_subscription_path,
                  alert: "Payment verification failed: #{payment_details[:error]}"
      return
    end

    payment = payment_details[:payment]

    # Verify payment is valid
    unless verify_payment_details(payment)
      redirect_to new_subscription_path,
                  alert: 'Payment verification failed: Invalid payment details'
      return
    end

    # Create subscription from verified payment
    @subscription = create_subscription_from_payment(payment)

    if @subscription.persisted?
      redirect_to subscription_success_path(@subscription),
                  notice: 'Payment successful! Your subscription is now active.'
    else
      redirect_to new_subscription_path,
                  alert: "Subscription creation failed: #{@subscription.errors.full_messages.join(', ')}"
    end
  end

  # GET /subscriptions/:id/success
  def success
    @subscription = current_user.subscriptions.find(params[:id])
  end

  private

  def ensure_owner_role
    unless current_user.owner?
      redirect_to root_path, alert: 'Only business owners can subscribe'
    end
  end

  def set_subscription
    @subscription = Subscription.find(params[:id])
  end

  # Fetch payment from Moyasar API
  # Uses HTTP Basic Authentication with secret key
  def fetch_moyasar_payment(payment_id)
    require 'net/http'
    require 'json'
    require 'base64'

    uri = URI("#{Moyasar.api_url}/payments/#{payment_id}")

    # Create GET request
    request = Net::HTTP::Get.new(uri)

    # Basic Authentication: Base64(secret_key:)
    # Note the colon after secret key with empty password
    auth_string = Base64.strict_encode64("#{Moyasar.secret_key}:")
    request['Authorization'] = "Basic #{auth_string}"

    # Make HTTPS request
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    # Parse JSON response
    result = JSON.parse(response.body)

    if response.code == '200'
      { success: true, payment: result }
    else
      error_message = result['message'] || "HTTP #{response.code}"
      Rails.logger.error "Moyasar fetch error: #{error_message}"
      { success: false, error: error_message }
    end
  rescue StandardError => e
    Rails.logger.error "Moyasar API error: #{e.message}"
    { success: false, error: 'Failed to fetch payment details' }
  end

  # Verify payment matches expected values
  # CRITICAL SECURITY: Prevents payment amount tampering
  def verify_payment_details(payment)
    expected_amount = Moyasar.to_halalas(Moyasar.monthly_subscription_amount)
    expected_currency = 'SAR'

    # Check 1: Payment status must be 'paid'
    unless payment['status'] == 'paid'
      Rails.logger.warn "Payment #{payment['id']} status: #{payment['status']}, expected 'paid'"
      return false
    end

    # Check 2: Amount must match exactly
    unless payment['amount'] == expected_amount
      Rails.logger.warn "Payment #{payment['id']} amount mismatch: #{payment['amount']} vs #{expected_amount}"
      return false
    end

    # Check 3: Currency must be SAR
    unless payment['currency'] == expected_currency
      Rails.logger.warn "Payment #{payment['id']} currency: #{payment['currency']}, expected #{expected_currency}"
      return false
    end

    # Check 4: Payment not already used (prevents replay attacks)
    if Subscription.exists?(moyasar_payment_id: payment['id'])
      Rails.logger.warn "Payment #{payment['id']} already used"
      return false
    end

    true
  end

  # Create subscription from verified payment
  def create_subscription_from_payment(payment)
    current_user.subscriptions.create(
      status: :active,
      amount: Moyasar.to_sar(payment['amount']),
      currency: payment['currency'],
      moyasar_payment_id: payment['id'],
      current_period_start: Time.current,
      current_period_end: 1.month.from_now
    )
  rescue StandardError => e
    Rails.logger.error "Subscription creation failed: #{e.message}"
    Subscription.new(errors: { base: [e.message] })
  end
end
```

**Security Highlights**:

1. **Double Verification**: `verify_payment` (pre-redirect) + `callback` (post-redirect)
2. **Amount Validation**: Ensures user paid correct amount
3. **Replay Prevention**: Checks payment ID not already used
4. **Status Check**: Only accepts 'paid' status
5. **Logging**: All verification failures logged for debugging

---

### Step 6: Create Payment View

Create file `app/views/subscriptions/new.html.erb`:

```erb
<div class="max-w-2xl mx-auto p-6">
  <h1 class="text-3xl font-bold mb-6">Subscribe</h1>

  <div class="bg-white rounded-lg shadow-md p-6">
    <div class="mb-6">
      <h2 class="text-xl font-semibold mb-2">Monthly Subscription</h2>
      <p class="text-3xl font-bold text-blue-600">
        <%= number_to_currency(Moyasar.monthly_subscription_amount, unit: 'SAR ') %>
        <span class="text-sm font-normal text-gray-600">/ month</span>
      </p>
    </div>

    <!-- Error message container -->
    <div class="payment-error-message hidden bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
    </div>

    <!-- Moyasar payment form container -->
    <div data-controller="moyasar"
         data-moyasar-amount-value="<%= Moyasar.to_halalas(Moyasar.monthly_subscription_amount) %>"
         data-moyasar-currency-value="SAR"
         data-moyasar-description-value="Monthly Subscription - R_Booking"
         data-moyasar-publishable-key-value="<%= Moyasar.publishable_key %>"
         data-moyasar-callback-url-value="<%= callback_subscriptions_url %>"
         data-moyasar-metadata-value="<%= { user_id: current_user.id }.to_json %>">

      <!-- Moyasar will render the form here -->
      <div class="mysr-form"></div>
    </div>
  </div>
</div>
```

**Important Elements**:

1. **`data-controller="moyasar"`**: Connects to Stimulus controller
2. **`data-moyasar-*-value`**: Passes data to JavaScript
3. **Amount in halalas**: Moyasar requires smallest currency unit
4. **`.mysr-form`**: Where Moyasar renders the payment form
5. **Error container**: Shows validation/payment errors
6. **Metadata**: Additional tracking data (user_id, etc.)

---

### Step 7: Load Moyasar JavaScript Library

Add to `app/views/layouts/application.html.erb` in `<head>`:

```erb
<!-- Moyasar Payment Form Library -->
<script src="https://cdn.moyasar.com/mpf/1.16.0/moyasar.js"></script>
```

**Why CDN?** Moyasar provides their library via CDN. This ensures you're always using the latest secure version.

**Alternative**: Download and host yourself for offline capability, but you'll need to manually update.

---

### Step 8: Configure Routes

Add to `config/routes.rb`:

```ruby
resources :subscriptions, only: [:index, :new, :create, :show] do
  collection do
    post :start_trial           # For free trial
    post :verify_payment        # AJAX verification endpoint
    get :callback               # Moyasar redirect URL
  end

  member do
    get :success                # Success page
    delete :cancel              # Cancel subscription
  end
end

# Webhook endpoint (optional, for production)
post 'moyasar/webhooks', to: 'moyasar_webhooks#create'
```

**Route Purposes**:

- `POST /subscriptions/verify_payment`: Client-side AJAX verification
- `GET /subscriptions/callback`: Moyasar redirect after payment
- `GET /subscriptions/:id/success`: Success page
- `POST /moyasar/webhooks`: Webhook for payment status updates (production)

**Verify routes**:
```bash
bin/rails routes | grep subscription
```

---

## Code Explanation

### Understanding the Payment Flow

#### 1. User Visits Payment Page

```
GET /subscriptions/new
  → Renders view with Stimulus controller
  → Moyasar.js initializes payment form
```

#### 2. User Enters Card Details

- Handled entirely by Moyasar.js
- Card data never touches your server
- PCI compliant (Moyasar handles security)

#### 3. Payment Processing

```javascript
window.Moyasar.init({
  on_completed: async (payment) => {
    // Payment object contains:
    {
      id: 'pay_xxxxxx',
      status: 'paid',
      amount: 9900,  // in halalas
      currency: 'SAR',
      source: { ... }  // card details (masked)
    }
  }
})
```

#### 4. Client-Side Verification

```javascript
// Send payment to server for verification
POST /subscriptions/verify_payment
{
  payment_id: 'pay_xxxxxx',
  status: 'paid',
  amount: 9900,
  currency: 'SAR'
}
```

Server response:
```json
{
  "success": true,
  "payment_id": "pay_xxxxxx",
  "status": "paid"
}
```

#### 5. Server-Side Verification

```ruby
# Fetch payment from Moyasar API
GET https://api.moyasar.com/v1/payments/pay_xxxxxx
Authorization: Basic <Base64(secret_key:)>

# Verify:
payment['status'] == 'paid'          # ✓
payment['amount'] == 9900            # ✓
payment['currency'] == 'SAR'         # ✓
!Subscription.exists?(moyasar_payment_id: payment['id'])  # ✓
```

#### 6. Create Subscription

```ruby
Subscription.create!(
  user: current_user,
  status: :active,
  amount: 99.00,
  currency: 'SAR',
  moyasar_payment_id: 'pay_xxxxxx',
  current_period_start: Time.current,
  current_period_end: 1.month.from_now
)
```

### Why Double Verification?

**Scenario**: Malicious user tries to bypass payment

```javascript
// Attacker modifies JavaScript to skip verification
on_completed: async (payment) => {
  // Skip verification, go straight to callback
  window.location = '/subscriptions/callback?id=pay_fake123'
}
```

**Defense**:
```ruby
# callback action ALWAYS fetches from Moyasar API
payment = fetch_moyasar_payment(params[:id])
# payment will be invalid/not found
# subscription not created
```

**Result**: Attack prevented! Subscription only created if payment verified by Moyasar API.

---

## Security Measures

### 1. Never Trust Client Data

```ruby
# ❌ WRONG - Trust client amount
amount = params[:amount]  # Attacker sets to 1 halala!
```

```ruby
# ✅ CORRECT - Use server-defined amount
amount = Moyasar.to_halalas(Moyasar.monthly_subscription_amount)
```

### 2. Always Verify Payment Server-Side

```ruby
# Fetch payment from Moyasar (source of truth)
payment = fetch_moyasar_payment(payment_id)

# Verify ALL critical fields
payment['status'] == 'paid'
payment['amount'] == expected_amount
payment['currency'] == expected_currency
```

### 3. Prevent Replay Attacks

```ruby
# Check payment not already used
if Subscription.exists?(moyasar_payment_id: payment['id'])
  # Someone already created subscription with this payment
  return false
end
```

### 4. Use HTTPS in Production

- OAuth2 and payments REQUIRE HTTPS
- Protects data in transit
- Required by PCI compliance

### 5. Secure Credential Storage

```ruby
# ✅ CORRECT - Encrypted credentials
Rails.application.credentials.moyasar_secret_key

# ❌ WRONG - Environment variable (visible in logs)
ENV['MOYASAR_SECRET_KEY']

# ❌ WRONG - Hardcoded (in version control)
"sk_live_xxxxxx"
```

### 6. Log Security Events

```ruby
Rails.logger.warn "Payment verification failed: amount mismatch"
Rails.logger.error "Moyasar API error: #{error.message}"
```

Monitor logs for:
- Failed verifications (potential fraud)
- API errors (system issues)
- Replay attack attempts

---

## Testing

### Test Cards (Moyasar Test Mode)

Moyasar provides test cards that simulate different scenarios:

#### Successful Payment

```
Card Number: 4111 1111 1111 1111 (Visa)
Card Number: 5200 0000 0000 0000 (Mastercard)
CVV: 123 (any 3 digits)
Expiry: 12/25 (any future date)
```

#### Failed Payment

```
Card Number: 4000 0000 0000 0002
CVV: 123
Expiry: 12/25
```

### Manual Testing Steps

1. **Start Server**:
   ```bash
   bin/dev
   ```

2. **Visit Payment Page**:
   ```
   http://localhost:3000/subscriptions/new
   ```

3. **Fill Payment Form**:
   - Card: `4111 1111 1111 1111`
   - CVV: `123`
   - Expiry: `12/25`
   - Name: `Test User`

4. **Submit Payment**

5. **Check Console**:
   ```bash
   bin/rails console
   Subscription.last
   # Should show new subscription with moyasar_payment_id
   ```

6. **Check Moyasar Dashboard**:
   - Visit https://dashboard.moyasar.com/
   - Go to **Payments**
   - Should see your test payment

### Testing Different Scenarios

#### Test 1: Successful Payment

```
Expected Result:
✓ Payment form submits
✓ verify_payment returns success
✓ Redirects to callback
✓ Subscription created
✓ Success page shown
```

#### Test 2: Failed Payment (Wrong Card)

```
Card: 4000 0000 0000 0002

Expected Result:
✗ Payment fails
✗ Error shown in form
✗ No subscription created
```

#### Test 3: Amount Tampering (Security Test)

```javascript
// In browser console, try to modify amount
document.querySelector('[data-moyasar-amount-value]')
        .setAttribute('data-moyasar-amount-value', '100')

Expected Result:
✗ verify_payment fails (amount mismatch)
✗ No subscription created
✗ Logged as security event
```

#### Test 4: Replay Attack (Security Test)

```ruby
# In Rails console
payment_id = Subscription.last.moyasar_payment_id

# Try to use same payment again
# Visit: http://localhost:3000/subscriptions/callback?id=#{payment_id}

Expected Result:
✗ verify_payment_details returns false
✗ Error: "Payment already used"
✗ No duplicate subscription
```

### Automated Tests

#### RSpec Example

```ruby
# spec/requests/subscriptions_spec.rb
RSpec.describe 'Subscriptions', type: :request do
  let(:user) { create(:user, role: :owner) }

  before { sign_in user }

  describe 'POST /subscriptions/verify_payment' do
    let(:payment_id) { 'pay_test123' }

    before do
      # Mock Moyasar API response
      allow_any_instance_of(SubscriptionsController)
        .to receive(:fetch_moyasar_payment)
        .and_return({
          success: true,
          payment: {
            'id' => payment_id,
            'status' => 'paid',
            'amount' => 9900,
            'currency' => 'SAR'
          }
        })
    end

    it 'verifies valid payment' do
      post verify_payment_subscriptions_path, params: {
        payment_id: payment_id
      }

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)['success']).to be true
    end

    it 'rejects payment with wrong amount' do
      # Mock wrong amount
      allow_any_instance_of(SubscriptionsController)
        .to receive(:fetch_moyasar_payment)
        .and_return({
          success: true,
          payment: {
            'id' => payment_id,
            'status' => 'paid',
            'amount' => 100,  # Wrong amount!
            'currency' => 'SAR'
          }
        })

      post verify_payment_subscriptions_path, params: {
        payment_id: payment_id
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['success']).to be false
    end
  end
end
```

---

## Production Deployment

### Pre-Deployment Checklist

- [ ] Get production Moyasar credentials (live keys)
- [ ] Add live keys to production credentials
- [ ] Ensure HTTPS is enabled
- [ ] Test with small real payment
- [ ] Set up webhook endpoint (optional but recommended)
- [ ] Monitor payment logs
- [ ] Set up error alerting (e.g., Sentry, Bugsnag)

### Production Credentials

```bash
# On production server
EDITOR=nano bin/rails credentials:edit --environment production
```

```yaml
moyasar_publishable_key: pk_live_YOUR_LIVE_KEY
moyasar_secret_key: sk_live_YOUR_LIVE_SECRET
```

### Environment-Specific Configuration

```ruby
# config/environments/production.rb
config.force_ssl = true  # Enforce HTTPS (required for payments)
```

### Webhook Setup (Optional but Recommended)

Webhooks notify your app when payment status changes (refunds, disputes, etc.).

#### 1. Create Webhook Controller

```ruby
# app/controllers/moyasar_webhooks_controller.rb
class MoyasarWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    # Verify webhook signature (important!)
    unless verify_webhook_signature
      head :unauthorized
      return
    end

    payload = JSON.parse(request.body.read)
    event_type = payload['type']
    payment = payload['data']

    case event_type
    when 'payment.paid'
      handle_payment_paid(payment)
    when 'payment.failed'
      handle_payment_failed(payment)
    when 'payment.refunded'
      handle_payment_refunded(payment)
    end

    head :ok
  end

  private

  def verify_webhook_signature
    # Moyasar signs webhooks with your secret key
    # Implement signature verification here
    true  # Placeholder
  end

  def handle_payment_paid(payment)
    # Update subscription status
    Rails.logger.info "Payment paid: #{payment['id']}"
  end

  def handle_payment_failed(payment)
    # Handle failed payment
    Rails.logger.warn "Payment failed: #{payment['id']}"
  end

  def handle_payment_refunded(payment)
    # Handle refund
    Rails.logger.info "Payment refunded: #{payment['id']}"
  end
end
```

#### 2. Configure Webhook in Moyasar Dashboard

1. Go to **Settings** → **Webhooks**
2. Add webhook URL: `https://yourdomain.com/moyasar/webhooks`
3. Select events: `payment.paid`, `payment.failed`, `payment.refunded`
4. Save

---

## Troubleshooting

### Error: "Missing entry: publishable_api_key is required"

**Cause**: Moyasar publishable key not configured.

**Solution**:
```bash
bin/rails credentials:edit
# Add: moyasar_publishable_key: pk_test_YOUR_KEY
# Restart server
```

### Error: "Amount below minimum"

**Cause**: Moyasar requires minimum 100 halalas (1 SAR).

**Solution**:
```ruby
# Check amount
Moyasar.to_halalas(0.50)  # Returns 50 - too low!
Moyasar.to_halalas(1.00)  # Returns 100 - minimum valid
```

### Payment Form Not Showing

**Check**:
1. Moyasar CDN script loaded:
   ```html
   <script src="https://cdn.moyasar.com/mpf/1.16.0/moyasar.js"></script>
   ```

2. Check browser console for errors

3. Verify publishable key:
   ```bash
   bin/rails console
   Moyasar.publishable_key
   ```

### Payment Succeeds but Subscription Not Created

**Debug**:
```ruby
# Check logs
tail -f log/development.log

# Look for:
# - "Payment verification failed"
# - "Amount mismatch"
# - "Payment already used"
```

**Common causes**:
- Amount configured incorrectly
- Payment ID already used
- Database error when creating subscription

### 3D Secure Not Working

**Cause**: 3D Secure requires HTTPS.

**Solution**: Use ngrok for local testing:
```bash
ngrok http 3000
# Use HTTPS URL in Google Console redirect URIs
```

---

## Summary

You've learned:

✅ How payment gateways work
✅ Moyasar integration architecture
✅ Double verification security pattern
✅ Client-side payment form with Stimulus
✅ Server-side payment verification
✅ Preventing common payment fraud
✅ Testing strategies
✅ Production deployment

### Key Takeaways

**Security First**:
- Never trust client data
- Always verify server-side
- Prevent replay attacks
- Log security events

**User Experience**:
- Embedded form (better than redirect)
- Clear error messages
- Test mode for development
- Smooth payment flow

**Production Ready**:
- Double verification
- Webhook support
- Error monitoring
- Comprehensive logging

---

## Additional Resources

- [Moyasar Documentation](https://docs.moyasar.com/)
- [Moyasar Dashboard](https://dashboard.moyasar.com/)
- [Moyasar API Reference](https://moyasar.com/docs/api/)
- [Payment Form Guide](https://docs.moyasar.com/guides/card-payments/basic-integration/)
- [PCI Compliance Guide](https://www.pcisecuritystandards.org/)

---

**Note**: This guide is based on the implementation in the r_booking Rails 8.1 application. Adapt as needed for your specific requirements.

**Happy coding!** 🚀
