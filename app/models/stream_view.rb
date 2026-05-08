# Records that a user viewed a live stream (once per user). Used to hide stream from feed after view.
# watched_seconds is capped by backend (30–90s). See docs/STREAM_AND_MOMENTS_SPEC.md
class StreamView < ApplicationRecord
  belongs_to :user
  belongs_to :live_stream

  validates :watched_seconds, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :viewed_at, presence: true
  validates :user_id, uniqueness: { scope: :live_stream_id, message: 'already viewed this stream' }
end
