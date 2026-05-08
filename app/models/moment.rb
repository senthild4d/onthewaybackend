# Moment: live-only clip on profile. No upload, no edit, no platform music.
# Audience: public | followers. Disappearing: 24h, 72h, 1_week, 1_month, 3_months, 6_months, 1_year, none.
# No archive; user can delete only. See docs/STREAM_AND_MOMENTS_SPEC.md
class Moment < ApplicationRecord
  belongs_to :user
  belongs_to :venue, optional: true
  belongs_to :event, optional: true

  attribute :projection, :string, default: 'flat'

  # Stories/moments can be either image or video.
  has_one_attached :image
  has_one_attached :video

  validates :audience, presence: true, inclusion: { in: %w[public followers] }
  validates :disappearing_duration, presence: true,
    inclusion: { in: %w[24h 72h 1_week 1_month 3_months 6_months 1_year none] }
  validates :projection, inclusion: { in: %w[flat equirectangular] }

  before_validation :set_expires_at, on: :create
  before_validation :refresh_expires_at_if_duration_changed, on: :update
  after_commit :enqueue_video_thumbnail_job, on: :create

  scope :visible, -> { where(deleted_at: nil) }
  scope :not_expired, -> { where('expires_at IS NULL OR expires_at > ?', Time.current) }
  scope :for_feed, -> { visible.not_expired }

  DISAPPEARING_DURATIONS = %w[24h 72h 1_week 1_month 3_months 6_months 1_year none].freeze

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def media_type
    return 'video' if video.attached?
    return 'image' if image.attached?
    'unknown'
  end

  def immersive?
    projection == 'equirectangular' && video.attached?
  end

  # Coordinates for map display: from venue or event
  def story_location
    if venue_id.present? && venue&.coordinates?
      { latitude: venue.latitude.to_f, longitude: venue.longitude.to_f }
    elsif event_id.present? && event
      loc = event.event_location
      loc ? { latitude: loc[:latitude], longitude: loc[:longitude] } : nil
    else
      nil
    end
  end

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  private

  def enqueue_video_thumbnail_job
    return unless video.attached?
    GenerateVideoThumbnailJob.perform_later(id)
  end

  def set_expires_at
    assign_expires_at_from_duration
  end

  def refresh_expires_at_if_duration_changed
    return unless disappearing_duration_changed?

    assign_expires_at_from_duration
  end

  def assign_expires_at_from_duration
    if disappearing_duration.blank? || disappearing_duration == 'none'
      self.expires_at = nil
      return
    end

    self.expires_at = case disappearing_duration
                      when '24h' then 24.hours.from_now
                      when '72h' then 72.hours.from_now
                      when '1_week' then 1.week.from_now
                      when '1_month' then 1.month.from_now
                      when '3_months' then 3.months.from_now
                      when '6_months' then 6.months.from_now
                      when '1_year' then 1.year.from_now
                      else nil
                      end
  end
end
