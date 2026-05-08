# Enforces stream rules: 1 hour per venue per day; view max 30–90s.
# When stream ends, caller must delete from Cloudflare and mark live_stream ended (no keeping recording).
# See docs/STREAM_AND_MOMENTS_SPEC.md
class StreamLimitService
  MAX_STREAM_SECONDS_PER_VENUE_PER_DAY = 1.hour.to_i
  VIEW_MAX_SECONDS_MIN = 30
  VIEW_MAX_SECONDS_MAX = 90
  DEFAULT_VIEW_MAX_SECONDS = 60

  class << self
    # Returns { allowed: true } or { allowed: false, error: "..." }.
    def can_start_stream?(venue_id)
      return { allowed: false, error: 'Venue not found' } if venue_id.blank?
      used = LiveStream.seconds_streamed_today_for_venue(venue_id)
      remaining = LiveStream.remaining_seconds_today_for_venue(venue_id)
      if remaining <= 0
        return { allowed: false, error: 'Daily stream limit reached (1 hour per venue per day)' }
      end
      { allowed: true, remaining_seconds: remaining }
    end

    # Clamp view max to 30–90. Can be configurable per venue/event later.
    def view_max_seconds(venue_id: nil, event_id: nil)
      # TODO: load from venue or event settings if needed
      DEFAULT_VIEW_MAX_SECONDS
    end

    def clamp_watched_seconds(seconds, venue_id: nil, event_id: nil)
      max = view_max_seconds(venue_id: venue_id, event_id: event_id)
      [seconds.to_i, 0].max.clamp(0, max)
    end

    # Call when stream ends: delete from Cloudflare, mark LiveStream ended, set duration. Stream is gone forever.
    def end_stream!(live_stream)
      return false unless live_stream.is_a?(LiveStream)
      duration = live_stream.duration_seconds || [Time.current - live_stream.started_at.to_time, 0].max.to_i
      live_stream.update!(status: 'ended', ended_at: Time.current, duration_seconds: duration)
      CloudflareStreamService.delete_live_input(live_stream.cloudflare_live_input_uid) if live_stream.cloudflare_live_input_uid.present?
      live_stream.update_column(:status, 'deleted')
      true
    rescue StandardError => e
      Rails.logger.error "StreamLimitService.end_stream! #{e.message}"
      false
    end
  end
end
