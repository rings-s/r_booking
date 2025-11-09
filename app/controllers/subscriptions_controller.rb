class SubscriptionsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_owner_role, only: [:new, :create]
  before_action :set_subscription, only: [:show, :cancel]

  # GET /subscriptions
  def index
    @subscriptions = current_user.subscriptions.order(created_at: :desc)
    @current_subscription = current_user.current_subscription
  end

  # GET /subscriptions/new
  def new
    # Check if user already has a valid subscription
    if current_user.subscribed?
      redirect_to subscription_path(current_user.current_subscription),
                  notice: t('subscriptions.already_subscribed')
      return
    end

    # Check if user is eligible for trial
    @trial_eligible = current_user.subscriptions.none?

    # User needs to pay for subscription or can start trial
    @subscription = Subscription.new(
      user: current_user,
      amount: Moyasar.monthly_subscription_amount,
      currency: 'SAR'
    )
  end

  # POST /subscriptions
  def create
    payment_token = params[:token]

    unless payment_token
      redirect_to new_subscription_path, alert: 'Payment failed. Please try again.'
      return
    end

    # Call Moyasar API to process payment
    payment_response = process_moyasar_payment(payment_token)

    if payment_response[:success]
      # Create subscription record
      @subscription = current_user.subscriptions.create!(
        status: :active,
        amount: Moyasar.monthly_subscription_amount,
        currency: 'SAR',
        moyasar_payment_id: payment_response[:payment_id],
        current_period_start: Time.current,
        current_period_end: 1.month.from_now
      )

      redirect_to subscription_success_path(@subscription),
                  notice: 'Payment successful! Your subscription is now active.'
    else
      redirect_to new_subscription_path,
                  alert: "Payment failed: #{payment_response[:error]}"
    end
  rescue StandardError => e
    Rails.logger.error "Subscription creation failed: #{e.message}"
    redirect_to new_subscription_path,
                alert: 'An error occurred while processing your payment. Please try again.'
  end

  # GET /subscriptions/:id
  def show
    unless @subscription.user == current_user || current_user.admin?
      redirect_to root_path, alert: 'You are not authorized to view this subscription.'
    end
  end

  # POST /subscriptions/verify_payment
  # Called by Moyasar Stimulus controller after payment completion
  # Verifies payment details before allowing redirect
  def verify_payment
    payment_id = params[:payment_id]

    unless payment_id.present?
      render json: { success: false, error: 'Payment ID is required' }, status: :bad_request
      return
    end

    # Fetch payment details from Moyasar API for verification
    payment_details = fetch_moyasar_payment(payment_id)

    if payment_details[:success]
      payment = payment_details[:payment]

      # Verify payment status, amount, and currency
      if verify_payment_details(payment)
        render json: {
          success: true,
          payment_id: payment['id'],
          status: payment['status']
        }
      else
        render json: {
          success: false,
          error: 'Payment verification failed: Invalid payment details'
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
  # Moyasar callback URL after payment completion
  # Fetches payment from Moyasar API and creates subscription
  def callback
    payment_id = params[:id]

    unless payment_id.present?
      redirect_to new_subscription_path, alert: 'Invalid payment reference'
      return
    end

    # Fetch and verify payment from Moyasar
    payment_details = fetch_moyasar_payment(payment_id)

    if payment_details[:success]
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
    else
      redirect_to new_subscription_path,
                  alert: "Payment verification failed: #{payment_details[:error]}"
    end
  end

  # GET /subscriptions/:id/success
  # Success page after subscription creation
  def success
    @subscription = current_user.subscriptions.find(params[:id])

    unless @subscription.user == current_user
      redirect_to root_path, alert: 'You are not authorized to view this subscription.'
    end
  end

  # DELETE /subscriptions/:id/cancel
  def cancel
    unless @subscription.user == current_user
      redirect_to root_path, alert: 'You are not authorized to cancel this subscription.'
      return
    end

    if @subscription.cancel!
      redirect_to subscriptions_path, notice: 'Your subscription has been cancelled.'
    else
      redirect_to subscription_path(@subscription), alert: 'Failed to cancel subscription.'
    end
  end

  # POST /subscriptions/start_trial
  def start_trial
    # Check if already subscribed
    if current_user.subscribed?
      redirect_to subscription_path(current_user.current_subscription),
                  alert: t('subscriptions.already_subscribed')
      return
    end

    # Try to create trial subscription
    trial_sub = current_user.get_or_create_trial_subscription

    if trial_sub
      redirect_to subscription_path(trial_sub),
                  notice: t('subscriptions.trial_started')
    else
      redirect_to new_subscription_path,
                  alert: t('subscriptions.trial_not_available')
    end
  end

  private

  def set_subscription
    @subscription = Subscription.find(params[:id])
  end

  def ensure_owner_role
    unless current_user.owner?
      redirect_to root_path, alert: 'Only business owners can subscribe.'
    end
  end

  # Fetch payment details from Moyasar API
  # Following official Moyasar documentation for server-side verification
  def fetch_moyasar_payment(payment_id)
    require 'net/http'
    require 'json'
    require 'base64'

    uri = URI("#{Moyasar.api_url}/payments/#{payment_id}")

    # Prepare GET request with Basic Auth
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Basic #{Base64.strict_encode64("#{Moyasar.secret_key}:")}"

    # Make API call
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    # Parse response
    result = JSON.parse(response.body)

    if response.code == '200'
      { success: true, payment: result }
    else
      error_message = result['message'] || "HTTP #{response.code}"
      Rails.logger.error "Moyasar fetch payment error: #{error_message}"
      { success: false, error: error_message }
    end
  rescue StandardError => e
    Rails.logger.error "Moyasar API error: #{e.message}"
    { success: false, error: 'Failed to fetch payment details' }
  end

  # Verify payment details match expected values
  # Critical security check to prevent payment manipulation
  def verify_payment_details(payment)
    expected_amount = Moyasar.to_halalas(Moyasar.monthly_subscription_amount)
    expected_currency = 'SAR'

    # Verify payment status
    unless payment['status'] == 'paid'
      Rails.logger.warn "Payment #{payment['id']} status is #{payment['status']}, expected 'paid'"
      return false
    end

    # Verify amount matches subscription price
    unless payment['amount'] == expected_amount
      Rails.logger.warn "Payment #{payment['id']} amount mismatch: got #{payment['amount']}, expected #{expected_amount}"
      return false
    end

    # Verify currency
    unless payment['currency'] == expected_currency
      Rails.logger.warn "Payment #{payment['id']} currency mismatch: got #{payment['currency']}, expected #{expected_currency}"
      return false
    end

    # Check if payment is already used
    if Subscription.exists?(moyasar_payment_id: payment['id'])
      Rails.logger.warn "Payment #{payment['id']} already used for existing subscription"
      return false
    end

    true
  end

  # Create subscription from verified Moyasar payment
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

  # Legacy method - kept for backward compatibility
  # TODO: Remove after migrating to new payment flow
  def process_moyasar_payment(token)
    require 'net/http'
    require 'json'
    require 'base64'

    uri = URI("#{Moyasar.api_url}/payments")

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request['Authorization'] = "Basic #{Base64.strict_encode64("#{Moyasar.secret_key}:")}"

    payment_data = {
      amount: Moyasar.to_halalas(Moyasar.monthly_subscription_amount),
      currency: 'SAR',
      description: 'Monthly Subscription - R_Booking',
      callback_url: subscriptions_callback_url,
      source: {
        type: 'token',
        token: token
      },
      metadata: {
        user_id: current_user.id,
        subscription_type: 'monthly'
      }
    }

    request.body = payment_data.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    result = JSON.parse(response.body)

    if response.code == '201' && result['status'] == 'paid'
      { success: true, payment_id: result['id'] }
    else
      error_message = result.dig('source', 'message') || result['message'] || 'Unknown error'
      { success: false, error: error_message }
    end
  rescue StandardError => e
    Rails.logger.error "Moyasar API error: #{e.message}"
    { success: false, error: 'Payment processing failed' }
  end
end
