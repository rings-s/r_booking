# Moyasar Payment Gateway Setup Guide

This guide explains how to configure Moyasar payment gateway for the R_Booking application.

## Prerequisites

- A Moyasar account (sign up at https://moyasar.com/)
- Access to your Moyasar dashboard

## Getting Your API Keys

### Production Keys

1. Log in to your Moyasar dashboard at https://dashboard.moyasar.com/
2. Navigate to **Settings** → **API Keys**
3. You'll find two types of keys:
   - **Publishable Key** (starts with `pk_live_...`)
   - **Secret Key** (starts with `sk_live_...`)

### Test Keys

For development and testing, use your test keys:
- **Test Publishable Key** (starts with `pk_test_...`)
- **Test Secret Key** (starts with `sk_test_...`)

**Important**: Never commit these keys to your repository!

## Configuration

### 1. Add Keys to Rails Credentials

Edit your Rails credentials file:

```bash
EDITOR=nano bin/rails credentials:edit
```

Add your Moyasar keys:

```yaml
# For development/testing (use test keys)
moyasar_publishable_key: pk_test_YOUR_TEST_PUBLISHABLE_KEY_HERE
moyasar_secret_key: sk_test_YOUR_TEST_SECRET_KEY_HERE

# For production (use live keys)
# moyasar_publishable_key: pk_live_YOUR_LIVE_PUBLISHABLE_KEY_HERE
# moyasar_secret_key: sk_live_YOUR_LIVE_SECRET_KEY_HERE
```

Save and close the editor (Ctrl+X, then Y, then Enter for nano).

### 2. Verify Configuration

The application accesses these keys through the `Moyasar` module defined in `config/initializers/moyasar.rb`:

```ruby
Moyasar.publishable_key  # Returns Rails.application.credentials.moyasar_publishable_key
Moyasar.secret_key       # Returns Rails.application.credentials.moyasar_secret_key
```

### 3. Test the Integration

1. Start your Rails server: `bin/dev`
2. Navigate to `/subscriptions/new`
3. You should see the Moyasar payment form
4. Use Moyasar's test card numbers to test payments:

#### Test Card Numbers

**Successful Payment:**
- Card Number: `4111 1111 1111 1111` (Visa)
- Card Number: `5200 0000 0000 0000` (Mastercard)
- CVV: Any 3 digits (e.g., `123`)
- Expiry: Any future date (e.g., `12/25`)

**Failed Payment:**
- Card Number: `4000 0000 0000 0002`
- CVV: Any 3 digits
- Expiry: Any future date

## Webhook Configuration (Optional)

For production deployments, configure webhooks to receive payment notifications:

1. In your Moyasar dashboard, go to **Settings** → **Webhooks**
2. Add your webhook URL: `https://yourdomain.com/moyasar/webhooks`
3. Select events to listen for:
   - `payment.paid`
   - `payment.failed`
   - `payment.authorized`

The webhook handler is implemented in `app/controllers/moyasar_webhooks_controller.rb`.

## Current Subscription Pricing

- **Monthly Subscription**: 99 SAR/month
- **Free Trial**: 2 weeks (no credit card required)

Pricing can be adjusted in `config/initializers/moyasar.rb`:

```ruby
def monthly_subscription_amount
  99.00  # Amount in SAR
end
```

## Currency

The application uses SAR (Saudi Riyal) as the default currency. Moyasar requires amounts in the smallest currency unit (halalas):

- 1 SAR = 100 Halalas
- The helper method `Moyasar.to_halalas(amount)` handles this conversion

## Supported Payment Methods

Currently configured payment methods:
- Credit Card (Visa, Mastercard)
- Mada (Saudi Arabia's local payment network)

You can modify supported methods in `app/javascript/controllers/moyasar_controller.js`:

```javascript
supported_networks: ['visa', 'mastercard', 'mada'],
methods: ['creditcard']
```

## Troubleshooting

### "Missing entry: publishable_api_key is required"

This error means the Moyasar publishable key is not configured in your credentials.
- Run: `EDITOR=nano bin/rails credentials:edit`
- Add your `moyasar_publishable_key`
- Restart your Rails server

### "Payment form not displaying"

1. Check browser console for JavaScript errors
2. Verify Moyasar CDN scripts are loading in `app/views/subscriptions/new.html.erb`
3. Ensure credentials are properly configured

### "Webhook not working"

1. Verify webhook URL is publicly accessible (not localhost)
2. Check webhook signature verification in `MoyasarWebhooksController`
3. Review webhook logs in Moyasar dashboard

## Resources

- [Moyasar Documentation](https://docs.moyasar.com/)
- [Moyasar Dashboard](https://dashboard.moyasar.com/)
- [Moyasar API Reference](https://moyasar.com/docs/api/)
- [Payment Form Documentation](https://moyasar.com/docs/payment-form/)

## Security Notes

1. **Never expose secret keys**: Secret keys should only be used server-side
2. **Use HTTPS**: Always use HTTPS in production for payment pages
3. **Verify webhooks**: Always verify webhook signatures to prevent tampering
4. **PCI Compliance**: Moyasar handles PCI compliance - never store card details yourself
