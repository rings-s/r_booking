class Subscription < ApplicationRecord
  belongs_to :user

  # Status enum: trial, active, past_due, cancelled, expired
  enum :status, { trial: 0, active: 1, past_due: 2, cancelled: 3, expired: 4 }

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true
  validates :status, presence: true

  # Scopes
  scope :active_subscriptions, -> { where(status: [:trial, :active]) }
  scope :valid_subscriptions, -> { where(status: [:trial, :active]).where('current_period_end > ?', Time.current) }

  # Check if subscription is currently valid (active or in trial)
  def valid_subscription?
    (trial? || active?) && current_period_end&.>(Time.current)
  end

  # Check if user is in trial period
  def in_trial?
    trial? && trial_ends_at&.>(Time.current)
  end

  # Check if subscription has ended
  def ended?
    cancelled? || expired? || (current_period_end && current_period_end < Time.current)
  end

  # Days remaining in current period
  def days_remaining
    return 0 unless current_period_end
    ((current_period_end - Time.current) / 1.day).to_i
  end

  # Cancel subscription
  def cancel!
    update(status: :cancelled, cancelled_at: Time.current)
  end

  # Mark subscription as expired
  def expire!
    update(status: :expired)
  end

  # Renew subscription for another month
  def renew!
    update(
      status: :active,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now
    )
  end
end
