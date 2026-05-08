class GroupChatMembership < ApplicationRecord
  # Associations
  belongs_to :group_chat
  belongs_to :user

  # Enums
  enum :role, { admin: 'admin', member: 'member' }, prefix: true

  # Validations
  validates :group_chat_id, presence: true
  validates :user_id, presence: true
  validates :role, presence: true, inclusion: { in: roles.keys }
  validates :user_id, uniqueness: { scope: :group_chat_id, message: "is already a member of this group chat" }
  validates :joined_at, presence: true

  # Callbacks
  before_validation :set_joined_at, on: :create

  def unread_count
    return 0 unless last_read_at

    group_chat.messages
          .where('created_at > ?', last_read_at)
          .where.not(user_id: user_id)
          .count
  end

  def mark_as_read
    update_column(:last_read_at, Time.current)
  end

  def mute!
    update_column(:is_muted, true)
  end

  def unmute!
    update_column(:is_muted, false)
  end

  def pin!
    update_column(:is_pinned, true)
  end

  def unpin!
    update_column(:is_pinned, false)
  end

  def star!
    update_column(:is_starred, true)
  end

  def unstar!
    update_column(:is_starred, false)
  end

  private

  def set_joined_at
    self.joined_at ||= Time.current
  end
end

