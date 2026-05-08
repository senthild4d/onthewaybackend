# frozen_string_literal: true

require 'open3'
require 'fileutils'

# Creates a 2:1 (equirectangular-container) MP4 from a normal flat video WITHOUT distortion:
# - Background: blurred, cropped-to-cover 2:1 fill from the same video.
# - Foreground: aspect-preserving scale-to-fit, centered (no stretching, no v360 reprojection).
#
# This is the safest "looks good on mobile" fallback when you only have one camera clip.
class PadBlurToEquirectangularVideoService
  OUTPUT_WIDTH = 3840
  OUTPUT_HEIGHT = 1920
  MAX_DURATION_SECONDS = 30

  class Error < StandardError; end

  def self.convert_to_tempfile(front_uploaded, blur_sigma: 20)
    raise Error, 'ffmpeg is not available' unless DualCameraVideoMergeService.ffmpeg_available?
    raise Error, 'front video is required' if front_uploaded.blank?
    raise Error, 'Upload must be multipart binary video data, not a path string' if front_uploaded.is_a?(String)

    Dir.mktmpdir('pad_blur_eq') do |dir|
      ext = DualCameraVideoMergeService.extension_for_upload(front_uploaded)
      in_path = File.join(dir, "front#{ext}")
      out_path = File.join(dir, 'equirect.mp4')

      DualCameraVideoMergeService.copy_upload!(front_uploaded, in_path)

      dur = DualCameraVideoMergeService.probe_duration_seconds(in_path)
      raise Error, 'Could not read video duration' if dur.nil? || dur <= 0
      raise Error, "Video must be #{MAX_DURATION_SECONDS}s or less" if dur > MAX_DURATION_SECONDS

      bg = "[0:v]scale=#{OUTPUT_WIDTH}:#{OUTPUT_HEIGHT}:force_original_aspect_ratio=increase," \
           "crop=#{OUTPUT_WIDTH}:#{OUTPUT_HEIGHT},setsar=1,format=yuv420p," \
           "boxblur=#{blur_sigma}:1[bg]"

      fg = "[0:v]scale=#{OUTPUT_WIDTH}:#{OUTPUT_HEIGHT}:force_original_aspect_ratio=decrease," \
           "pad=#{OUTPUT_WIDTH}:#{OUTPUT_HEIGHT}:(ow-iw)/2:(oh-ih)/2,setsar=1,format=yuv420p[fg]"

      filter = "#{bg};#{fg};[bg][fg]overlay=0:0[outv]"

      cmd = [
        'ffmpeg', '-y', '-hide_banner', '-loglevel', 'error',
        '-i', in_path,
        '-filter_complex', filter,
        '-map', '[outv]',
        '-map', '0:a?',
        '-c:v', 'libx264', '-preset', 'fast', '-crf', '23',
        '-c:a', 'aac', '-b:a', '128k',
        '-movflags', '+faststart',
        '-shortest',
        out_path
      ]

      _stdout, stderr, status = Open3.capture3(*cmd)
      if !(status.success? && File.exist?(out_path) && File.size(out_path).positive?)
        cmd_no_audio = cmd - ['-c:a', 'aac', '-b:a', '128k']
        cmd_no_audio += ['-an']
        _stdout2, stderr2, status2 = Open3.capture3(*cmd_no_audio)
        stderr = stderr2.presence || stderr
        status = status2
      end

      unless status.success? && File.exist?(out_path) && File.size(out_path).positive?
        raise Error, "ffmpeg failed: #{stderr.presence || 'unknown error'}"
      end

      result = Tempfile.new(['pad_blur_equirect', '.mp4'])
      result.close
      FileUtils.cp(out_path, result.path)
      result
    end
  end
end

