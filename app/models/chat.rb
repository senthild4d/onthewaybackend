class Chat < ApplicationRecord
  # Associations
  belongs_to :user1, class_name: 'User'
  belongs_to :user2, class_name: 'User'
  belongs_to :booking, optional: true
  has_many :messages, class_name: 'ChatMessage', dependent: :destroy

  # Validations
  validates :user1_id, presence: true
  validates :user2_id, presence: true
  validates :user1_id, uniqueness: { scope: [:user2_id, :booking_id], message: "chat already exists between these users" }
  validate :users_must_be_different
  validate :user1_id_less_than_user2_id

  # Scopes
  scope :for_user, ->(user) { where(user1_id: user.id).or(where(user2_id: user.id)) }
  scope :active, ->(user) { 
    for_user(user).where(
      "(user1_id = ? AND user1_archived = false) OR (user2_id = ? AND user2_archived = false)",
      user.id, user.id
    )
  }
  scope :pinned, ->(user) {
    for_user(user).where(
      "(user1_id = ? AND user1_pinned = true) OR (user2_id = ? AND user2_pinned = true)",
      user.id, user.id
    )
  }
  scope :recent, -> { order(last_message_at: :desc, created_at: :desc) }

  # Callbacks
  before_validation :ensure_user1_less_than_user2
  after_create :update_last_message_at

  def other_user(user)
    user.id == user1_id ? user2 : user1
  end

  def blocked_by?(user)
    if user.id == user1_id
      user1_blocked?
    elsif user.id == user2_id
      user2_blocked?
    else
      false
    end
  end

  def block!(user)
    if user.id == user1_id
      update_column(:user1_blocked, true)
    elsif user.id == user2_id
      update_column(:user2_blocked, true)
    end
  end

  def unblock!(user)
    if user.id == user1_id
      update_column(:user1_blocked, false)
    elsif user.id == user2_id
      update_column(:user2_blocked, false)
    end
  end

  def muted_by?(user)
    if user.id == user1_id
      user1_muted?
    elsif user.id == user2_id
      user2_muted?
    else
      false
    end
  end

  def mute!(user)
    if user.id == user1_id
      update_column(:user1_muted, true)
    elsif user.id == user2_id
      update_column(:user2_muted, true)
    end
  end

  def unmute!(user)
    if user.id == user1_id
      update_column(:user1_muted, false)
    elsif user.id == user2_id
      update_column(:user2_muted, false)
    end
  end

  def pinned_by?(user)
    if user.id == user1_id
      user1_pinned?
    elsif user.id == user2_id
      user2_pinned?
    else
      false
    end
  end

  def pin!(user)
    if user.id == user1_id
      update_column(:user1_pinned, true)
    elsif user.id == user2_id
      update_column(:user2_pinned, true)
    end
  end

  def unpin!(user)
    if user.id == user1_id
      update_column(:user1_pinned, false)
    elsif user.id == user2_id
      update_column(:user2_pinned, false)
    end
  end

  def archived_by?(user)
    if user.id == user1_id
      user1_archived?
    elsif user.id == user2_id
      user2_archived?
    else
      false
    end
  end

  def archive!(user)
    if user.id == user1_id
      update_column(:user1_archived, true)
    elsif user.id == user2_id
      update_column(:user2_archived, true)
    end
  end

  def unarchive!(user)
    if user.id == user1_id
      update_column(:user1_archived, false)
    elsif user.id == user2_id
      update_column(:user2_archived, false)
    end
  end

  def unread_count_for(user)
    messages.where.not(sender_id: user.id)
            .where(is_read: false)
            .count
  end

  def mark_as_read_for(user)
    messages.where.not(sender_id: user.id)
            .where(is_read: false)
            .update_all(is_read: true, read_at: Time.current)
    update_column(:last_message_at, Time.current)
  end

  def update_last_message_at
    update_column(:last_message_at, Time.current) if last_message_at.nil?
  end

  private

  def ensure_user1_less_than_user2
    return unless user1_id.present? && user2_id.present?
    
    if user1_id > user2_id
      self.user1_id, self.user2_id = user2_id, user1_id
    end
  end

  def users_must_be_different
    if user1_id == user2_id
      errors.add(:base, "Cannot create chat with the same user")
    end
  end

  def user1_id_less_than_user2_id
    return unless user1_id.present? && user2_id.present?
    return unless user1_id > user2_id

    errors.add(:base, "Invalid user ordering for chat")
  end
end

