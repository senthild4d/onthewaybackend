class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :related, polymorphic: true, optional: true

  TYPES = %w[
    property_approved
    property_rejected
    property_sold
    viewing_requested
    viewing_confirmed
    viewing_cancelled
    viewing_completed
    favorite_added
    account_update
    system
    other
  ].freeze

  validates :notification_type, presence: true
  validates :title, presence: true

  scope :unread, -> { where(read: false) }
  scope :read_only, -> { where(read: true) }
  scope :recent, -> { order(created_at: :desc) }
  scope :of_type, ->(type) { where(notification_type: type) }

  def mark_read!
    return if read?
    update!(read: true, read_at: Time.current)
  end

  def self.mark_all_read_for(user)
    where(user_id: user.id, read: false).update_all(read: true, read_at: Time.current)
  end
end
