# frozen_string_literal: true

# Pre-generates video thumbnail (preview) when a video is uploaded.
# Uses ActiveStorage::Preview with ffmpeg - requires ffmpeg to be installed.
# The preview is generated and stored; subsequent URL requests serve the cached variant.
class GenerateVideoThumbnailJob < ApplicationJob
  queue_as :default

  def perform(moment_id)
    moment = Moment.find_by(id: moment_id)
    return unless moment&.video&.attached?

    moment.video.preview(resize_to_limit: [400, 400], format: :jpeg).processed
  rescue ActiveStorage::FileNotFoundError, ActiveStorage::InvariableError,
         ActiveStorage::UnrepresentableError, ActiveStorage::UnpreviewableError,
         LoadError => e
    Rails.logger.warn "GenerateVideoThumbnailJob: Could not generate preview for moment #{moment_id}: #{e.message}"
  end
end
