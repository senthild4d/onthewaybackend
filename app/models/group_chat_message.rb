class GroupChatMessage < ApplicationRecord
  # Associations
  belongs_to :group_chat
  belongs_to :user
  belongs_to :reply_to, class_name: 'GroupChatMessage', optional: true
  has_many :replies, class_name: 'GroupChatMessage', foreign_key: 'reply_to_id', dependent: :nullify
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
  validates :group_chat_id, presence: true
  validates :user_id, presence: true
  validates :content, presence: true
  validates :message_type, presence: true, inclusion: { in: message_types.keys }

  # Scopes
  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :oldest_first, -> { order(created_at: :asc) }

  # Callbacks
  after_create :update_group_chat_last_message_at

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
    user_id == user.id && created_at > 15.minutes.ago
  end

  def forwarded?
    forwarded_from_id.present?
  end

  private

  def update_group_chat_last_message_at
    group_chat.update_column(:last_message_at, created_at)
  end
end

