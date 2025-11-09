class MoyasarWebhooksController < ApplicationController
  # Skip CSRF token verification for webhooks
  skip_before_action :verify_authenticity_token
  before_action :verify_moyasar_signature

  # POST /moyasar/webhooks
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

  def handle_payment_paid(payment_data)
    payment_id = payment_data['id']
    user_id = payment_data.dig('metadata', 'user_id')

    return unless user_id

    user = User.find_by(id: user_id)
    return unless user

    # Find or create subscription
    subscription = user.subscriptions.find_by(moyasar_payment_id: payment_id)

    if subscription
      # Update existing subscription
      subscription.update(
        status: :active,
        current_period_start: Time.current,
        current_period_end: 1.month.from_now
      )
    else
      # Create new subscription
      user.subscriptions.create!(
        status: :active,
        amount: Moyasar.to_sar(payment_data['amount']),
        currency: payment_data['currency'],
        moyasar_payment_id: payment_id,
        current_period_start: Time.current,
        current_period_end: 1.month.from_now
      )
    end

    Rails.logger.info "Payment successful for user #{user_id}: #{payment_id}"
  end

  def handle_payment_failed(payment_data)
    payment_id = payment_data['id']
    user_id = payment_data.dig('metadata', 'user_id')

    Rails.logger.warn "Payment failed for user #{user_id}: #{payment_id}"

    return unless user_id

    user = User.find_by(id: user_id)
    return unless user

    # Mark subscription as past_due if it exists
    subscription = user.subscriptions.find_by(moyasar_payment_id: payment_id)
    subscription&.update(status: :past_due)
  end

  def handle_payment_refunded(payment_data)
    payment_id = payment_data['id']
    user_id = payment_data.dig('metadata', 'user_id')

    Rails.logger.info "Payment refunded for user #{user_id}: #{payment_id}"

    return unless user_id

    user = User.find_by(id: user_id)
    return unless user

    # Cancel subscription if refunded
    subscription = user.subscriptions.find_by(moyasar_payment_id: payment_id)
    subscription&.cancel!
  end
end
