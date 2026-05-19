class Property < ApplicationRecord
  belongs_to :owner, class_name: 'User'
  belongs_to :approved_by, class_name: 'User', optional: true
  belongs_to :rejected_by, class_name: 'User', optional: true
  belongs_to :sold_by, class_name: 'User', optional: true
  belongs_to :archived_by, class_name: 'User', optional: true

  has_many_attached :images
  has_one_attached :video
  has_many :favorites, dependent: :destroy
  has_many :viewings, class_name: 'PropertyViewing', dependent: :destroy

  enum :approval_status, {
    draft: 'draft',
    pending_review: 'pending_review',
    approved: 'approved',
    rejected: 'rejected',
    archived: 'archived'
  }, prefix: true

  enum :purpose, { sale: 'sale', rent: 'rent' }, prefix: true
  enum :listing_status, { active: 'active', sold: 'sold', archived: 'archived' }, prefix: true
  # Same values as moments.projection — equirectangular 2:1 video for venue_360_viewer.html
  enum :video_projection, { flat: 'flat', equirectangular: 'equirectangular' }, prefix: true

  validates :title, presence: true, length: { maximum: 255 }
  validates :currency, presence: true
  validates :approval_status, inclusion: { in: approval_statuses.keys }
  validates :purpose, inclusion: { in: purposes.keys }
  validates :listing_status, inclusion: { in: listing_statuses.keys }
  validates :video_projection, inclusion: { in: %w[flat equirectangular] }
  validates :bedrooms, :bathrooms, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :area_sqft, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :area_sqm, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :latitude, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }, allow_nil: true
  validates :longitude, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }, allow_nil: true
  validates :year_built, numericality: { only_integer: true, greater_than_or_equal_to: 1600 }, allow_nil: true
  validates :floor, numericality: { only_integer: true, greater_than_or_equal_to: -5 }, allow_nil: true
  validates :total_floors, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :parking_spaces, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  validate :images_count_limit
  validate :images_size_limit
  validate :video_size_limit
  validate :video_content_type
  validate :features_format

  before_validation :normalize_features_values

  scope :visible_to_public, -> { where(approval_status: 'approved', listing_status: 'active') }

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

  def mark_sold!(by:)
    update!(
      listing_status: 'sold',
      sold_by: by,
      sold_at: Time.current
    )
  end

  def archive!(by:)
    update!(
      listing_status: 'archived',
      archived_by: by,
      archived_at: Time.current
    )
  end

  def unarchive!
    update!(
      listing_status: 'active',
      archived_by: nil,
      archived_at: nil
    )
  end

  def full_address
    [address1, address2, city, region, postal_code, country].compact.join(', ')
  end

  def normalized_features
    self.class.normalize_features_hash(features)
  end

  def self.normalize_features_hash(features)
    return {} if features.blank?

    boolean = ActiveModel::Type::Boolean.new
    features.each_with_object({}) do |(key, value), result|
      result[key.to_s] = boolean.cast(value)
    end
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

  def features_format
    return if features.blank?
    return if features.is_a?(Hash)
    errors.add(:features, 'must be an object')
  end

  def normalize_features_values
    return if features.blank?

    self.features = self.class.normalize_features_hash(features)
  end
end

