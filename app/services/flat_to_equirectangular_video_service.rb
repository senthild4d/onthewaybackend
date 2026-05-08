# frozen_string_literal: true

require 'open3'
require 'fileutils'

# "Fake" equirectangular conversion for a normal (flat) camera video:
# - Forces output to a 2:1 frame (e.g. 3840x1920) by stretching the source.
# - Tags the resulting story as equirectangular for immersive playback pipelines.
# This does NOT create true 360° content; it only produces a 2:1 video container.
class FlatToEquirectangularVideoService
  OUTPUT_WIDTH = 3840
  OUTPUT_HEIGHT = 1920
  MAX_DURATION_SECONDS = 30

  class Error < StandardError; end

  def self.convert_to_tempfile(front_uploaded)
    raise Error, 'ffmpeg is not available' unless DualCameraVideoMergeService.ffmpeg_available?
    raise Error, 'front video is required' if front_uploaded.blank?
    raise Error, 'Upload must be multipart binary video data, not a path string' if front_uploaded.is_a?(String)

    Dir.mktmpdir('flat_to_eq') do |dir|
      ext = DualCameraVideoMergeService.extension_for_upload(front_uploaded)
      in_path = File.join(dir, "front#{ext}")
      out_path = File.join(dir, 'equirect.mp4')

      DualCameraVideoMergeService.copy_upload!(front_uploaded, in_path)

      dur = DualCameraVideoMergeService.probe_duration_seconds(in_path)
      raise Error, 'Could not read video duration' if dur.nil? || dur <= 0
      raise Error, "Video must be #{MAX_DURATION_SECONDS}s or less" if dur > MAX_DURATION_SECONDS

      # Stretch to a 2:1 frame. This intentionally distorts aspect ratio to meet immersive players'
      # equirectangular expectations.
      vf = "scale=#{OUTPUT_WIDTH}:#{OUTPUT_HEIGHT},setsar=1,format=yuv420p"

      cmd = [
        'ffmpeg', '-y', '-hide_banner', '-loglevel', 'error',
        '-i', in_path,
        '-vf', vf,
        '-c:v', 'libx264', '-preset', 'fast', '-crf', '23',
        '-movflags', '+faststart',
        '-c:a', 'aac', '-b:a', '128k',
        out_path
      ]

      _stdout, stderr, status = Open3.capture3(*cmd)
      unless status.success? && File.exist?(out_path) && File.size(out_path).positive?
        # Fallback: source may not have audio
        cmd_no_audio = cmd - ['-c:a', 'aac', '-b:a', '128k']
        cmd_no_audio += ['-an']
        _stdout2, stderr2, status2 = Open3.capture3(*cmd_no_audio)
        unless status2.success? && File.exist?(out_path) && File.size(out_path).positive?
          raise Error, "ffmpeg failed: #{stderr2.presence || stderr.presence || 'unknown error'}"
        end
      end

      result = Tempfile.new(['flat_equirect', '.mp4'])
      result.close
      FileUtils.cp(out_path, result.path)
      return result
    end
  end
end

