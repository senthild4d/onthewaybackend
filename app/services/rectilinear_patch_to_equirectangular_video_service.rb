# frozen_string_literal: true

require 'open3'
require 'fileutils'

# Creates an "immersive-compatible" equirectangular (2:1) MP4 from a normal (flat) camera video:
# - Background: blurred 2:1 fill derived from the same video (no distortion artifacts).
# - Foreground: rectilinear projection mapped onto an equirectangular sphere using ffmpeg v360
#   (so it looks like a window into a sphere rather than a stretched frame).
#
# This is NOT true 360° capture; it's a single-view patch rendered into an equirectangular container.
class RectilinearPatchToEquirectangularVideoService
  OUTPUT_WIDTH = 3840
  OUTPUT_HEIGHT = 1920
  MAX_DURATION_SECONDS = 30

  class Error < StandardError; end

  def self.convert_to_tempfile(front_uploaded, yaw: 0, pitch: 0, h_fov: 90, v_fov: 60, blur_sigma: 20)
    raise Error, 'ffmpeg is not available' unless DualCameraVideoMergeService.ffmpeg_available?
    raise Error, 'front video is required' if front_uploaded.blank?
    raise Error, 'Upload must be multipart binary video data, not a path string' if front_uploaded.is_a?(String)

    Dir.mktmpdir('rect_patch_eq') do |dir|
      ext = DualCameraVideoMergeService.extension_for_upload(front_uploaded)
      in_path = File.join(dir, "front#{ext}")
      out_path = File.join(dir, 'equirect.mp4')

      DualCameraVideoMergeService.copy_upload!(front_uploaded, in_path)

      dur = DualCameraVideoMergeService.probe_duration_seconds(in_path)
      raise Error, 'Could not read video duration' if dur.nil? || dur <= 0
      raise Error, "Video must be #{MAX_DURATION_SECONDS}s or less" if dur > MAX_DURATION_SECONDS

      # Build a nice-looking blurred background without stretching the main content:
      # - scale to cover OUTPUT (force_original_aspect_ratio=increase)
      # - crop center to exact 2:1
      # - blur
      bg = "[0:v]scale=#{OUTPUT_WIDTH}:#{OUTPUT_HEIGHT}:force_original_aspect_ratio=increase," \
           "crop=#{OUTPUT_WIDTH}:#{OUTPUT_HEIGHT},setsar=1,format=yuv420p," \
           "boxblur=#{blur_sigma}:1[bg]"

      # Foreground: map the flat video to an equirectangular projection via v360.
      # v360 option names differ across ffmpeg builds; try likely input names.
      tried = []
      success = false

      input_variants = %w[rectilinear flat rect].freeze

      input_variants.each do |input_name|
        FileUtils.rm_f(out_path)

        # v360 renders "outside FOV" as black. Key that black to transparent so our blurred
        # background remains visible behind the patch.
        # Note: `colorkey` similarity may need tuning across encodes; keep conservative defaults.
        fg = "[0:v]v360=input=#{input_name}:output=equirect:w=#{OUTPUT_WIDTH}:h=#{OUTPUT_HEIGHT}:" \
             "yaw=#{yaw}:pitch=#{pitch}:h_fov=#{h_fov}:v_fov=#{v_fov}," \
             "setsar=1,format=rgba,colorkey=0x000000:0.22:0.0[fg]"

        filter = "#{bg};#{fg};[bg][fg]overlay=0:0:format=auto[outv]"

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
          # Fallback: source may not have audio
          cmd_no_audio = cmd - ['-c:a', 'aac', '-b:a', '128k']
          cmd_no_audio += ['-an']
          _stdout2, stderr2, status2 = Open3.capture3(*cmd_no_audio)
          stderr = stderr2.presence || stderr
          status = status2
        end

        tried << { input: input_name, stderr: stderr.to_s }
        next unless status.success? && File.exist?(out_path) && File.size(out_path).positive?

        success = true
        break
      end

      unless success
        last = tried.last
        raise Error,
              "ffmpeg failed (v360 unsupported/variant mismatch). Tried input=#{input_variants.join(' -> ')}. " \
              "Last error: #{last ? last[:stderr] : 'unknown error'}"
      end

      result = Tempfile.new(['rect_patch_equirect', '.mp4'])
      result.close
      FileUtils.cp(out_path, result.path)
      return result
    end
  end
end

