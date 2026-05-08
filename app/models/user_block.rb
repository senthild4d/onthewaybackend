class UserBlock < ApplicationRecord
  # Associations
  belongs_to :blocker, class_name: 'User'
  belongs_to :blocked, class_name: 'User'

  # Validations
  validates :blocker_id, presence: true
  validates :blocked_id, presence: true
  validates :blocked_id, uniqueness: { scope: :blocker_id, message: "user is already blocked" }
  validate :cannot_block_self

  # Scopes
  scope :by_blocker, ->(user) { where(blocker_id: user.id) }
  scope :blocked_users, ->(user) { where(blocker_id: user.id).includes(:blocked) }

  def self.blocked?(blocker, blocked)
    exists?(blocker_id: blocker.id, blocked_id: blocked.id)
  end

  def self.blocked_by?(user, other_user)
    exists?(blocker_id: other_user.id, blocked_id: user.id)
  end

  private

  def cannot_block_self
    if blocker_id == blocked_id
      errors.add(:base, "Cannot block yourself")
    end
  end
end

