class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [ :google_oauth2 ]

  enum :role, { client: 0, owner: 1, admin: 2 }

  has_many :businesses, dependent: :destroy
  has_many :bookings, dependent: :destroy
  has_many :subscriptions, dependent: :destroy

  # Find existing user by OAuth credentials or email (for linking accounts)
  def self.find_existing_oauth_user(auth)
    # First, try to find user by provider and uid
    user = where(provider: auth.provider, uid: auth.uid).first

    # If not found, try to find by email and link the account
    if user.nil? && auth.info.email.present?
      user = find_by(email: auth.info.email)
      if user
        # Link the OAuth account to the existing user
        user.update(
          provider: auth.provider,
          uid: auth.uid,
          name: auth.info.name || user.name,
          avatar_url: auth.info.image || user.avatar_url
        )
      end
    end

    user
  end

  # Legacy method for backwards compatibility (creates user with default client role)
  def self.from_omniauth(auth)
    user = find_existing_oauth_user(auth)

    # If still not found, create a new user with default client role
    user ||= create do |new_user|
      new_user.email = auth.info.email
      new_user.password = Devise.friendly_token[0, 20]
      new_user.name = auth.info.name
      new_user.avatar_url = auth.info.image
      new_user.provider = auth.provider
      new_user.uid = auth.uid
      # If you are using confirmable and the provider(s) you use validate emails,
      # uncomment the line below to skip the confirmation emails.
      # new_user.skip_confirmation!
    end

    user
  end

  # Subscription helper methods

  # Get current active subscription
  def current_subscription
    subscriptions.valid_subscriptions.order(created_at: :desc).first
  end

  # Check if user has a valid subscription (active or trial)
  def subscribed?
    return true if admin? # Admins don't need subscriptions
    return true if client? # Clients don't need subscriptions
    return false unless owner? # Only owners need subscriptions

    current_subscription&.valid_subscription? || false
  end

  # Check if user is in trial period
  def on_trial?
    return false unless owner?
    current_subscription&.in_trial? || false
  end

  # Get or create trial subscription (2 weeks free)
  def get_or_create_trial_subscription
    return nil unless owner?

    # Check if user already has a subscription
    existing_sub = current_subscription
    return existing_sub if existing_sub

    # Check if user ever had a subscription (no multiple trials)
    return nil if subscriptions.any?

    # Create new trial subscription (2 weeks)
    subscriptions.create!(
      status: :trial,
      amount: 99.00,
      currency: "SAR",
      trial_ends_at: 2.weeks.from_now,
      current_period_start: Time.current,
      current_period_end: 2.weeks.from_now
    )
  end

  # Check if subscription is expiring soon (less than 3 days)
  def subscription_expiring_soon?
    return false unless owner?
    sub = current_subscription
    return false unless sub
    sub.days_remaining <= 3 && sub.days_remaining > 0
  end

  # Get subscription status message
  def subscription_status_message
    return nil unless owner?

    sub = current_subscription
    return "No active subscription. Please subscribe to create businesses." unless sub

    if sub.in_trial?
      "Trial period: #{sub.days_remaining} days remaining"
    elsif sub.valid_subscription?
      "Active subscription: #{sub.days_remaining} days remaining"
    elsif sub.ended?
      "Subscription expired. Please renew to continue."
    else
      "Subscription status unknown"
    end
  end
end
