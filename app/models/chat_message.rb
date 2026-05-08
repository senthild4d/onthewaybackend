class ChatMessage < ApplicationRecord
  # Associations
  belongs_to :chat
  belongs_to :sender, class_name: 'User'
  belongs_to :reply_to, class_name: 'ChatMessage', optional: true
  has_many :replies, class_name: 'ChatMessage', foreign_key: 'reply_to_id', dependent: :nullify
  belongs_to :forwarded_from, polymorphic: true, optional: true

  # Enums
  enum :message_type, {
    text: 'text',
    image: 'image',
    video: 'video',
    audio: 'audio',
    location: 'location'
  }, prefix: true

  # Validations
  validates :chat_id, presence: true
  validates :sender_id, presence: true
  validates :content, presence: true
  validates :message_type, presence: true, inclusion: { in: message_types.keys }

  # Scopes
  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :oldest_first, -> { order(created_at: :asc) }
  scope :unread, -> { where(is_read: false) }

  # Callbacks
  after_create :update_chat_last_message_at, :mark_as_read_for_sender

  def soft_delete
    update_column(:deleted_at, Time.current)
  end

  def deleted?
    deleted_at.present?
  end

  def edit!(new_content)
    update!(
      content: new_content,
      is_edited: true,
      edited_at: Time.current
    )
  end

  def can_edit?(user)
    sender_id == user.id && created_at > 15.minutes.ago
  end

  def mark_as_read!
    return if is_read?

    update_columns(is_read: true, read_at: Time.current)
  end

  def forwarded?
    forwarded_from_id.present?
  end

  private

  def update_chat_last_message_at
    chat.update_column(:last_message_at, created_at)
  end

  def mark_as_read_for_sender
    # Messages are automatically read for the sender
    update_column(:is_read, true) if sender_id == chat.user1_id || sender_id == chat.user2_id
  end
end

