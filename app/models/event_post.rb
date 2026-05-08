class EventPost < ApplicationRecord
  belongs_to :event
  belongs_to :user
  
  # Active Storage for photos
  has_many_attached :photos
  
  # Associations for likes and comments (if needed in future)
  has_many :likes, as: :likeable, dependent: :destroy
  has_many :liked_by_users, through: :likes, source: :user
  
  # Validations
  validates :event_id, presence: true
  validates :user_id, presence: true
  validates :content, length: { maximum: 5000 }, allow_blank: true
  validates :status, presence: true, inclusion: { in: %w[active hidden deleted] }
  validate :content_or_photos_present
  validate :photos_count_limit
  validate :photo_size_limit
  
  # Enums
  enum :status, { active: 'active', hidden: 'hidden', deleted: 'deleted' }, prefix: true
  
  # Scopes
  scope :active, -> { where(status: 'active', deleted_at: nil) }
  scope :visible, -> { where(status: 'active', deleted_at: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user) { where(user_id: user.id) }
  scope :not_deleted, -> { where(deleted_at: nil) }
  
  # Filter out posts from blocked users
  scope :excluding_blocked_users, ->(user) {
    return all unless user.present?
    blocked_ids = user.blocked_users_ids
    return all if blocked_ids.empty?
    where.not(user_id: blocked_ids)
  }
  
  # Filter out posts where the user is blocked by the post creator
  scope :visible_to_user, ->(user) {
    return all unless user.present?
    excluding_blocked_users(user)
  }
  
  # Callbacks
  before_validation :set_default_status, on: :create
  
  # Methods
  def soft_delete
    update_columns(
      status: 'deleted',
      deleted_at: Time.current
    )
  end
  
  def deleted?
    deleted_at.present? || status_deleted?
  end
  
  def has_photos?
    photos.attached?
  end
  
  def photos_count
    photos.count
  end
  
  def likes_count
    likes.count
  end
  
  def user_liked?(user)
    likes.exists?(user: user)
  end
  
  def photo_urls
    return [] unless photos.attached?
    
    photos.map do |photo|
      Rails.application.routes.url_helpers.rails_blob_url(photo, only_path: false)
    rescue => e
      Rails.logger.error "Error generating photo URL: #{e.message}"
      nil
    end.compact
  end
  
  private
  
  def content_or_photos_present
    if content.blank? && !photos.attached?
      errors.add(:base, "Post must have either content or photos")
    end
  end
  
  def photos_count_limit
    if photos.attached? && photos.count > 10
      errors.add(:photos, "cannot exceed 10 photos per post")
    end
  end
  
  def photo_size_limit
    return unless photos.attached?
    
    photos.each do |photo|
      if photo.byte_size > 10.megabytes
        errors.add(:photos, "each photo must be less than 10MB")
        break
      end
    end
  end
  
  def set_default_status
    self.status ||= 'active'
  end
end


