# frozen_string_literal: true

require 'open3'
require 'fileutils'

# Merges back-camera (fullscreen) + front-camera (picture-in-picture) into one MP4.
# Requires ffmpeg on the server (see Dockerfile).
class DualCameraVideoMergeService
  MAX_DURATION_SECONDS = 30
  OUTPUT_WIDTH = 1080
  OUTPUT_HEIGHT = 1920
  PIP_WIDTH = 304

  class Error < StandardError; end

  def self.merge_to_tempfile(back_uploaded, front_uploaded)
    raise Error, 'ffmpeg is not available' unless ffmpeg_available?
    [back_uploaded, front_uploaded].each do |u|
      if u.is_a?(String)
        raise Error,
              'Invalid upload: received text instead of file bytes. Use multipart/form-data with binary video fields.'
      end
    end

    Dir.mktmpdir('dual_cam') do |dir|
      back_ext = extension_for_upload(back_uploaded)
      front_ext = extension_for_upload(front_uploaded)
      back_path = File.join(dir, "back#{back_ext}")
      front_path = File.join(dir, "front#{front_ext}")
      out_path = File.join(dir, 'merged.mp4')

      copy_upload!(back_uploaded, back_path)
      copy_upload!(front_uploaded, front_path)

      dur_back = probe_duration_seconds(back_path)
      dur_front = probe_duration_seconds(front_path)
      raise Error, 'Could not read back camera video duration' if dur_back.nil? || dur_back <= 0
      raise Error, 'Could not read front camera video duration' if dur_front.nil? || dur_front <= 0
      raise Error, "Back camera video must be #{MAX_DURATION_SECONDS}s or less" if dur_back > MAX_DURATION_SECONDS
      raise Error, "Front camera video must be #{MAX_DURATION_SECONDS}s or less" if dur_front > MAX_DURATION_SECONDS

      filter = "[0:v]scale=#{OUTPUT_WIDTH}:#{OUTPUT_HEIGHT}:force_original_aspect_ratio=decrease," \
               "pad=#{OUTPUT_WIDTH}:#{OUTPUT_HEIGHT}:(ow-iw)/2:(oh-ih)/2,setsar=1,format=yuv420p[bg];" \
               "[1:v]scale=#{PIP_WIDTH}:-2,format=yuv420p[pip];" \
               '[bg][pip]overlay=W-w-24:24[outv]'

      cmd = [
        'ffmpeg', '-y', '-hide_banner', '-loglevel', 'error',
        '-i', back_path,
        '-i', front_path,
        '-filter_complex', filter,
        '-map', '[outv]',
        '-map', '0:a?',
        '-c:v', 'libx264', '-preset', 'fast', '-crf', '23',
        '-c:a', 'aac', '-b:a', '128k',
        '-shortest',
        out_path
      ]

      _stdout, stderr, status = Open3.capture3(*cmd)
      unless status.success? && File.exist?(out_path) && File.size(out_path).positive?
        raise Error, "ffmpeg failed: #{stderr.presence || 'unknown error'}"
      end

      result = Tempfile.new(['dual_cam_merged', '.mp4'])
      result.close
      FileUtils.cp(out_path, result.path)
      return result
    end
  end

  def self.extension_for_upload(uploaded)
    return '.mp4' unless uploaded.respond_to?(:original_filename)

    File.extname(uploaded.original_filename.to_s).presence || '.mp4'
  end

  def self.copy_upload!(uploaded, dest_path)
    raise Error, 'Invalid upload object' if uploaded.is_a?(String)

    if uploaded.respond_to?(:tempfile) && uploaded.tempfile
      tf = uploaded.tempfile
      tf.open if tf.closed?
      tf.rewind
      FileUtils.cp(tf.path, dest_path)
    elsif uploaded.respond_to?(:path) && uploaded.path.present? && File.exist?(uploaded.path)
      FileUtils.cp(uploaded.path, dest_path)
    else
      File.binwrite(dest_path, uploaded.read)
      uploaded.rewind if uploaded.respond_to?(:rewind)
    end
  end

  def self.ffmpeg_available?
    system('ffmpeg', '-hide_banner', '-version', out: File::NULL, err: File::NULL)
  end

  def self.probe_duration_seconds(path)
    stdout, _stderr, status = Open3.capture3(
      'ffprobe', '-v', 'error',
      '-show_entries', 'format=duration',
      '-of', 'default=noprint_wrappers=1:nokey=1',
      path.to_s
    )
    return nil unless status.success?

    stdout.strip.to_f
  rescue StandardError
    nil
  end
end
