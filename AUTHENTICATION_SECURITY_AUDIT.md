# Authentication Security Audit & Implementation Guide

## Current Authentication Status

### ✅ What's Already Secure

#### 1. User Password Authentication (Devise with bcrypt)

**Current Implementation:**
```ruby
# app/models/user.rb
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [:google_oauth2]
end
```

**Database Schema:**
```ruby
# db/schema.rb
t.string "encrypted_password", default: "", null: false
```

**Gemfile:**
```ruby
gem "bcrypt", "~> 3.1.7"
gem "devise", "~> 4.9"
```

**Why This Is Secure:**
- ✅ Devise uses bcrypt for password hashing (same as `has_secure_password`)
- ✅ Passwords are **never** stored in plain text
- ✅ Uses `encrypted_password` column (industry standard)
- ✅ bcrypt is slow by design (prevents brute-force attacks)
- ✅ Automatic salt generation (unique per password)
- ✅ Cost factor of 12 (2^12 = 4096 iterations)

**Under the Hood:**
```ruby
# When user signs up:
user.password = "my_secure_password"
# Devise/bcrypt converts to:
user.encrypted_password = "$2a$12$K9h8YjZEHLFhbKvJ4tQk3.nI7xJQk..."
# Format: $algorithm$cost$salt+hash

# On sign in:
input_password = "my_secure_password"
bcrypt_compares(input_password, user.encrypted_password)  # => true/false
```

---

## ⚠️ Security Issues Found

### 1. CRITICAL: Webhook Signature Verification Disabled

**Location:** [app/controllers/moyasar_webhooks_controller.rb:30-44](app/controllers/moyasar_webhooks_controller.rb#L30-L44)

**Current Code:**
```ruby
def verify_moyasar_signature
  # Moyasar sends webhooks with a signature in the header
  # For production, implement signature verification
  # signature = request.headers['X-Moyasar-Signature']
  # payload = request.body.read
  # expected_signature = OpenSSL::HMAC.hexdigest('SHA256', Moyasar.secret_key, payload)
  #
  # unless ActiveSupport::SecurityUtils.secure_compare(signature, expected_signature)
  #   head :unauthorized
  #   return
  # end

  # For now, just log the webhook
  Rails.logger.info "Moyasar webhook received: #{params[:type]}"
end
```

**Risk:** 🚨 **HIGH - Anyone can send fake webhook requests to your app**

**Attack Scenario:**
```bash
# Attacker sends fake webhook to activate subscription without payment
curl -X POST https://yourdomain.com/moyasar/webhooks \
  -H "Content-Type: application/json" \
  -d '{
    "type": "payment.paid",
    "data": {
      "id": "fake_payment_123",
      "amount": 9900,
      "metadata": {"user_id": 5}
    }
  }'

# Result: User gets free subscription! 💸
```

**Solution Required:** ✅ Implement HMAC signature verification (see fixes below)

---

## 🔧 Required Security Fixes

### Fix 1: Enable Webhook Signature Verification

Update `app/controllers/moyasar_webhooks_controller.rb`:

```ruby
class MoyasarWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_moyasar_signature

  def create
    event_type = params[:type]
    payment_data = params[:data]

    case event_type
    when 'payment.paid'
      handle_payment_paid(payment_data)
    when 'payment.failed'
      handle_payment_failed(payment_data)
    when 'payment.refunded'
      handle_payment_refunded(payment_data)
    else
      Rails.logger.info "Unhandled webhook event: #{event_type}"
    end

    head :ok
  rescue StandardError => e
    Rails.logger.error "Webhook processing error: #{e.message}"
    head :unprocessable_entity
  end

  private

  def verify_moyasar_signature
    # Get signature from webhook header
    signature = request.headers['X-Moyasar-Signature']

    unless signature.present?
      Rails.logger.warn "Webhook rejected: Missing signature"
      head :unauthorized
      return
    end

    # Read raw request body (before params parsing)
    payload = request.body.read
    request.body.rewind  # Reset for later reading

    # Calculate expected signature using HMAC-SHA256
    expected_signature = OpenSSL::HMAC.hexdigest(
      'SHA256',
      Moyasar.webhook_secret,  # Add this to config/initializers/moyasar.rb
      payload
    )

    # Timing-safe comparison (prevents timing attacks)
    unless ActiveSupport::SecurityUtils.secure_compare(signature, expected_signature)
      Rails.logger.warn "Webhook rejected: Invalid signature"
      Rails.logger.debug "Expected: #{expected_signature}, Got: #{signature}"
      head :unauthorized
      return
    end

    Rails.logger.info "Moyasar webhook verified: #{params[:type]}"
  end

  # ... rest of the methods
end
```

### Fix 2: Add Webhook Secret to Configuration

Update `config/initializers/moyasar.rb`:

```ruby
module Moyasar
  class << self
    def publishable_key
      key = Rails.application.credentials.moyasar_publishable_key
      if key.blank? && Rails.env.development?
        Rails.logger.warn "⚠️  Moyasar publishable key not configured"
        return "pk_test_PLEASE_CONFIGURE_YOUR_KEY"
      end
      key
    end

    def secret_key
      key = Rails.application.credentials.moyasar_secret_key
      if key.blank? && Rails.env.development?
        Rails.logger.warn "⚠️  Moyasar secret key not configured"
        return "sk_test_PLEASE_CONFIGURE_YOUR_KEY"
      end
      key
    end

    # NEW: Add webhook secret for signature verification
    def webhook_secret
      secret = Rails.application.credentials.moyasar_webhook_secret
      if secret.blank?
        if Rails.env.production?
          raise "Moyasar webhook secret not configured! Add to credentials."
        else
          Rails.logger.warn "⚠️  Moyasar webhook secret not configured"
          return "whsec_test_placeholder"
        end
      end
      secret
    end

    def api_url
      'https://api.moyasar.com/v1'
    end

    def monthly_subscription_amount
      99.00
    end

    def to_halalas(amount_in_sar)
      (amount_in_sar * 100).to_i
    end

    def to_sar(amount_in_halalas)
      (amount_in_halalas / 100.0).round(2)
    end
  end
end
```

### Fix 3: Add Webhook Secret to Credentials

```bash
EDITOR=nano bin/rails credentials:edit
```

Add:
```yaml
moyasar_publishable_key: pk_test_YOUR_KEY
moyasar_secret_key: sk_test_YOUR_SECRET
moyasar_webhook_secret: whsec_YOUR_WEBHOOK_SECRET  # Get from Moyasar dashboard
```

**Where to get webhook secret:**
1. Log in to Moyasar Dashboard
2. Go to **Settings** → **Webhooks**
3. Create or view webhook
4. Copy the **Webhook Secret** (starts with `whsec_`)

---

## 🔐 When to Use `has_secure_password`

### Devise vs has_secure_password

| Feature | Devise | has_secure_password |
|---------|--------|---------------------|
| Password hashing | ✅ bcrypt | ✅ bcrypt |
| Reset password | ✅ Built-in | ❌ Manual |
| Remember me | ✅ Built-in | ❌ Manual |
| Confirmable | ✅ Built-in | ❌ Manual |
| OAuth support | ✅ OmniAuth | ❌ Manual |
| **Use case** | Full auth system | Simple password field |

**Verdict:** For `User` model, **keep Devise** (you have it right!)

### Where You SHOULD Use has_secure_password

#### Use Case 1: API Tokens

If you need API authentication for mobile apps or third-party integrations:

```ruby
# app/models/api_token.rb
class ApiToken < ApplicationRecord
  belongs_to :user

  has_secure_password :token

  # Generate random token on creation
  before_create :generate_token_digest

  private

  def generate_token_digest
    self.token = SecureRandom.urlsafe_base64(32)
  end
end
```

Migration:
```ruby
create_table :api_tokens do |t|
  t.references :user, null: false, foreign_key: true
  t.string :token_digest  # has_secure_password uses #{attribute}_digest
  t.string :name  # "Mobile App", "Third-party Integration"
  t.datetime :last_used_at
  t.datetime :expires_at
  t.timestamps
end
```

Usage:
```ruby
# Create token
token = user.api_tokens.create!(name: "Mobile App")
# Returns plaintext token ONCE (never stored)
plaintext_token = token.token

# Authenticate API request
ApiToken.find_by(id: token_id)&.authenticate(provided_token)
```

#### Use Case 2: Service Accounts

For background jobs or service-to-service authentication:

```ruby
# app/models/service_account.rb
class ServiceAccount < ApplicationRecord
  has_secure_password

  validates :name, presence: true, uniqueness: true
end
```

#### Use Case 3: Admin PIN Codes

For additional admin verification:

```ruby
# app/models/user.rb
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Additional security for admin actions
  has_secure_password :admin_pin, validations: false

  def verify_admin_pin(pin)
    return false unless admin?
    authenticate_admin_pin(pin)
  end
end
```

Migration:
```ruby
add_column :users, :admin_pin_digest, :string
```

---

## 🛡️ Password Security Best Practices

### 1. Password Strength Requirements

Add to `config/initializers/devise.rb`:

```ruby
Devise.setup do |config|
  # Minimum password length
  config.password_length = 12..128  # Increased from default 6

  # Password complexity (add gem 'strong_password')
  # config.password_complexity = {
  #   digit: 1,
  #   lowercase: 1,
  #   uppercase: 1,
  #   symbol: 1
  # }
end
```

### 2. Rate Limiting (Prevent Brute Force)

Add gem:
```ruby
# Gemfile
gem 'rack-attack'
```

Configure:
```ruby
# config/initializers/rack_attack.rb
class Rack::Attack
  # Throttle login attempts for a given email
  throttle('logins/email', limit: 5, period: 20.seconds) do |req|
    if req.path == '/users/sign_in' && req.post?
      req.params['user']['email'].to_s.downcase.gsub(/\s+/, "")
    end
  end

  # Block IPs making too many requests
  throttle('req/ip', limit: 300, period: 5.minutes) do |req|
    req.ip
  end
end
```

### 3. Two-Factor Authentication (Future Enhancement)

If you need 2FA, add:
```ruby
# Gemfile
gem 'devise-two-factor'
gem 'rqrcode'  # Already have this!
```

### 4. Session Security

Update `config/initializers/session_store.rb`:
```ruby
Rails.application.config.session_store :cookie_store,
  key: '_r_booking_session',
  secure: Rails.env.production?,  # HTTPS only in production
  httponly: true,  # Prevent JavaScript access
  same_site: :lax  # CSRF protection
```

### 5. Password Reset Security

Current Devise config is good, but ensure:
```ruby
# config/initializers/devise.rb
config.reset_password_within = 6.hours  # Short expiry
config.paranoid = true  # Don't reveal if email exists
```

---

## 🧪 Testing Security

### Test Webhook Signature Verification

```ruby
# test/controllers/moyasar_webhooks_controller_test.rb
require 'test_helper'

class MoyasarWebhooksControllerTest < ActionDispatch::IntegrationTest
  test "rejects webhook without signature" do
    post moyasar_webhooks_path, params: { type: 'payment.paid' }
    assert_response :unauthorized
  end

  test "rejects webhook with invalid signature" do
    post moyasar_webhooks_path,
      params: { type: 'payment.paid' },
      headers: { 'X-Moyasar-Signature' => 'invalid_signature' }

    assert_response :unauthorized
  end

  test "accepts webhook with valid signature" do
    payload = { type: 'payment.paid', data: { id: 'pay_123' } }.to_json
    signature = OpenSSL::HMAC.hexdigest('SHA256', Moyasar.webhook_secret, payload)

    post moyasar_webhooks_path,
      params: JSON.parse(payload),
      headers: {
        'Content-Type' => 'application/json',
        'X-Moyasar-Signature' => signature
      }

    assert_response :success
  end
end
```

### Test Password Security

```ruby
# test/models/user_test.rb
require 'test_helper'

class UserTest < ActiveSupport::TestCase
  test "password is encrypted" do
    user = User.create!(
      email: 'test@example.com',
      password: 'SecurePassword123!',
      password_confirmation: 'SecurePassword123!'
    )

    assert_not_equal 'SecurePassword123!', user.encrypted_password
    assert user.encrypted_password.start_with?('$2a$')  # bcrypt format
  end

  test "cannot authenticate with wrong password" do
    user = users(:one)  # From fixtures
    assert_not user.valid_password?('wrong_password')
  end

  test "OAuth users get random password" do
    auth = OmniAuth::AuthHash.new({
      provider: 'google_oauth2',
      uid: '123456',
      info: { email: 'oauth@example.com', name: 'OAuth User' }
    })

    user = User.from_omniauth(auth)
    assert user.encrypted_password.present?
    assert_not_equal '', user.encrypted_password
  end
end
```

---

## 📋 Security Checklist

### Current Status

- [x] User passwords encrypted with bcrypt
- [x] Devise properly configured
- [x] OAuth integration secure
- [x] Random passwords for OAuth users
- [x] Password reset token protection
- [x] CSRF protection enabled
- [ ] **Webhook signature verification** (NEEDS FIX)
- [ ] Rate limiting (recommended)
- [ ] Two-factor authentication (future)
- [ ] API token authentication (if needed)
- [ ] Session security hardening (recommended)

### Production Deployment Checklist

Before deploying:

- [ ] Enable webhook signature verification
- [ ] Add `moyasar_webhook_secret` to production credentials
- [ ] Test webhook signature with Moyasar test events
- [ ] Enable HTTPS (required for Devise + OAuth)
- [ ] Set `config.force_ssl = true` in production.rb
- [ ] Configure rate limiting with rack-attack
- [ ] Set secure session cookie options
- [ ] Review Devise paranoid mode settings
- [ ] Implement account lockout after failed attempts
- [ ] Add security headers (helmet-rails or secure_headers gem)
- [ ] Set up monitoring for failed auth attempts
- [ ] Configure log retention and rotation

---

## 🔗 References

- [Rails Active Model has_secure_password](https://guides.rubyonrails.org/active_model_basics.html#securepassword)
- [Devise Documentation](https://github.com/heartcombo/devise)
- [bcrypt](https://github.com/bcrypt-ruby/bcrypt-ruby)
- [OWASP Password Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)
- [Moyasar Webhook Security](https://docs.moyasar.com/webhooks/security/)

---

## Summary

**Your authentication is mostly secure**, but you have **one critical vulnerability**:

1. ✅ **User passwords**: Secure (Devise + bcrypt)
2. ✅ **OAuth integration**: Secure
3. 🚨 **Webhook verification**: **DISABLED - MUST FIX BEFORE PRODUCTION**

**Action Required:**
1. Implement webhook signature verification (see Fix 1-3 above)
2. Add webhook secret to credentials
3. Test thoroughly before deploying

**Optional Improvements:**
- Add rate limiting with rack-attack
- Implement 2FA for admin users
- Add API token authentication if building mobile app

---

**Last Updated:** 2025-11-11
**Rails Version:** 8.1.1
**Security Audit by:** Claude Code
