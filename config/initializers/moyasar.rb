# Moyasar Payment Gateway Configuration
# API Documentation: https://docs.moyasar.com/
#
# IMPORTANT: You need to configure your Moyasar API keys in Rails credentials.
# See MOYASAR_SETUP.md for detailed setup instructions.
#
# To add your keys:
# 1. Run: EDITOR=nano bin/rails credentials:edit
# 2. Add your keys:
#    moyasar_publishable_key: pk_test_YOUR_KEY_HERE
#    moyasar_secret_key: sk_test_YOUR_SECRET_HERE
# 3. Save and restart your Rails server

module Moyasar
  class << self
    def publishable_key
      key = Rails.application.credentials.moyasar_publishable_key

      # In development, provide a placeholder if no key is configured
      # This allows the payment form to render (but won't process payments)
      if key.blank? && Rails.env.development?
        Rails.logger.warn "⚠️  Moyasar publishable key not configured. See MOYASAR_SETUP.md"
        return "pk_test_PLEASE_CONFIGURE_YOUR_MOYASAR_KEY"
      end

      key
    end

    def secret_key
      key = Rails.application.credentials.moyasar_secret_key

      # In development, provide a placeholder if no key is configured
      if key.blank? && Rails.env.development?
        Rails.logger.warn "⚠️  Moyasar secret key not configured. See MOYASAR_SETUP.md"
        return "sk_test_PLEASE_CONFIGURE_YOUR_MOYASAR_SECRET"
      end

      key
    end

    def api_url
      'https://api.moyasar.com/v1'
    end

    # Monthly subscription amount in SAR
    def monthly_subscription_amount
      99.00
    end

    # Convert amount to smallest currency unit (halalas for SAR)
    # 1 SAR = 100 Halalas
    def to_halalas(amount_in_sar)
      (amount_in_sar * 100).to_i
    end

    # Convert from halalas to SAR
    def to_sar(amount_in_halalas)
      (amount_in_halalas / 100.0).round(2)
    end
  end
end
