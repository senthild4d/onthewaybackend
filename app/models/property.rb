class Property < ApplicationRecord
  belongs_to :owner, class_name: 'User'
  belongs_to :approved_by, class_name: 'User', optional: true
  belongs_to :rejected_by, class_name: 'User', optional: true

  has_many_attached :images
  has_one_attached :video

  enum :approval_status, {
    draft: 'draft',
    pending_review: 'pending_review',
    approved: 'approved',
    rejected: 'rejected',
    archived: 'archived'
  }, prefix: true

  validates :title, presence: true, length: { maximum: 255 }
  validates :currency, presence: true
  validates :approval_status, inclusion: { in: approval_statuses.keys }
  validates :bedrooms, :bathrooms, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :area_sqft, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :latitude, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }, allow_nil: true
  validates :longitude, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }, allow_nil: true

  validate :images_count_limit
  validate :images_size_limit
  validate :video_size_limit
  validate :video_content_type

  scope :visible_to_public, -> { where(approval_status: 'approved') }

  def coordinates?
    latitude.present? && longitude.present?
  end

  def submit_for_review!
    update!(approval_status: 'pending_review', submitted_at: Time.current)
  end

  def approve!(by:)
    update!(
      approval_status: 'approved',
      approved_by: by,
      approved_at: Time.current,
      rejected_by: nil,
      rejected_at: nil,
      rejection_reason: nil
    )
  end

  def reject!(by:, reason:)
    update!(
      approval_status: 'rejected',
      rejected_by: by,
      rejected_at: Time.current,
      rejection_reason: reason.to_s.presence
    )
  end

  def full_address
    [address1, address2, city, region, postal_code, country].compact.join(', ')
  end

  private

  def images_count_limit
    return unless images.attached?
    errors.add(:images, 'cannot exceed 20 images') if images.count > 20
  end

  def images_size_limit
    return unless images.attached?
    images.each do |img|
      next unless img.byte_size > 10.megabytes
      errors.add(:images, 'each image must be <= 10MB')
      break
    end
  end

  def video_size_limit
    return unless video.attached?
    errors.add(:video, 'must be <= 200MB') if video.byte_size > 200.megabytes
  end

  def video_content_type
    return unless video.attached?
    ct = video.content_type.to_s
    return if ct.start_with?('video/')
    errors.add(:video, 'must be a video file')
  end
end

