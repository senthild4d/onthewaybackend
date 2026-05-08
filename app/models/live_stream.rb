# Represents a live stream (Cloudflare). 1 hour per venue per calendar day.
# When stream ends, delete from Cloudflare and mark ended; do not keep recording.
# See docs/STREAM_AND_MOMENTS_SPEC.md
class LiveStream < ApplicationRecord
  belongs_to :venue
  belongs_to :event, optional: true
  has_many :stream_views, dependent: :destroy

  validates :cloudflare_live_input_uid, presence: true, uniqueness: true
  validates :started_at, presence: true
  validates :status, presence: true, inclusion: { in: %w[live ended deleted] }

  scope :live, -> { where(status: 'live') }
  scope :ended, -> { where(status: 'ended') }
  scope :for_venue_today, ->(venue_id) {
    where(venue_id: venue_id)
      .where('started_at >= ? AND started_at < ?', Time.current.beginning_of_day, Time.current.end_of_day)
  }
  scope :ended_today_for_venue, ->(venue_id) {
    for_venue_today(venue_id).ended
  }

  def self.seconds_streamed_today_for_venue(venue_id)
    ended_today_for_venue(venue_id).sum(:duration_seconds).to_i
  end

  def self.remaining_seconds_today_for_venue(venue_id)
    limit_seconds = 1.hour.to_i
    [limit_seconds - seconds_streamed_today_for_venue(venue_id), 0].max
  end
end
