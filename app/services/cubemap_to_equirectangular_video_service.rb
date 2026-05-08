# frozen_string_literal: true

require 'open3'
require 'fileutils'

# Converts six synchronized cubemap-face MP4s (front, right, back, left, top, bottom) into one
# equirectangular 360° video for immersive playback. Requires ffmpeg with v360 filter (4.2+).
# Face order matches ffmpeg v360 input=c6x1: Front, Right, Back, Left, Top, Bottom.
class CubemapToEquirectangularVideoService
  MAX_DURATION_SECONDS = 30
  FACE_SIZE = 640
  OUTPUT_WIDTH = 3840
  OUTPUT_HEIGHT = 1920

  FACE_KEYS = %i[front right back left top bottom].freeze

  class Error < StandardError; end

  def self.build_filter(v360_extra:)
    parts = []
    6.times do |i|
      parts << "[#{i}:v]scale=#{FACE_SIZE}:#{FACE_SIZE}:force_original_aspect_ratio=decrease," \
               "pad=#{FACE_SIZE}:#{FACE_SIZE}:(ow-iw)/2:(oh-ih)/2,setsar=1,format=yuv420p[v#{i}]"
    end
    parts << '[v0][v1][v2][v3][v4][v5]hstack=inputs=6[row]'

    v360 = +"[row]v360=input=c6x1:output=equirect:w=#{OUTPUT_WIDTH}:h=#{OUTPUT_HEIGHT}"
    v360 << ":#{v360_extra}" if v360_extra.present?
    v360 << ',format=yuv420p[outv]'
    parts << v360

    parts.join(';')
  end

  def self.convert_to_tempfile(faces)
    raise Error, 'ffmpeg is not available' unless DualCameraVideoMergeService.ffmpeg_available?

    front = faces[:front]
    raise Error, 'Missing required face upload: front' if front.blank?

    # For any missing face, fall back to the provided front face so we can still generate a
    # valid c6x1 input for ffmpeg's v360 filter.
    effective_faces = FACE_KEYS.to_h do |k|
      [k, faces[k].presence || front]
    end

    FACE_KEYS.each do |k|
      u = effective_faces[k]
      raise Error, 'Face uploads must be binary multipart files, not path strings' if u.is_a?(String)
    end

    Dir.mktmpdir('cubemap_6') do |dir|
      paths = {}
      FACE_KEYS.each do |key|
        u = effective_faces[key]
        ext = DualCameraVideoMergeService.extension_for_upload(u)
        path = File.join(dir, "#{key}#{ext}")
        DualCameraVideoMergeService.copy_upload!(u, path)
        paths[key] = path
      end

      durations = FACE_KEYS.map { |k| DualCameraVideoMergeService.probe_duration_seconds(paths[k]) }
      if durations.any? { |d| d.nil? || d <= 0 }
        raise Error, 'Could not read duration for one or more face videos'
      end

      max_d = durations.max
      min_d = durations.min
      raise Error, "Each face video must be #{MAX_DURATION_SECONDS}s or less" if max_d > MAX_DURATION_SECONDS
      # If face durations differ, trim all faces to the minimum duration so we can still generate
      # a synchronized output (mobile uploads may have slight timing differences).
      target_duration = [min_d, MAX_DURATION_SECONDS].min

      out_path = File.join(dir, 'equirect.mp4')

      inputs = []
      FACE_KEYS.each do |k|
        # Place -t before -i so it applies to that specific input.
        inputs += ['-t', target_duration.to_s, '-i', paths[k]]
      end

      # ffmpeg builds differ: some v360 versions support `interpolation=`, others use `interp=`,
      # and some support neither. Try in order from most explicit to most compatible.
      tried = []
      v360_extras = [
        'interpolation=linear',
        'interp=linear',
        nil
      ]

      success = false
      v360_extras.each do |extra|
        FileUtils.rm_f(out_path)
        filter = build_filter(v360_extra: extra)
        cmd = [
          'ffmpeg', '-y', '-hide_banner', '-loglevel', 'error'
        ] + inputs + [
          '-filter_complex', filter,
          '-map', '[outv]',
          '-an',
          '-c:v', 'libx264', '-preset', 'fast', '-crf', '23',
          '-movflags', '+faststart',
          '-shortest',
          out_path
        ]

        _stdout, stderr, status = Open3.capture3(*cmd)
        tried << { v360_extra: extra, stderr: stderr.to_s }

        if status.success? && File.exist?(out_path) && File.size(out_path).positive?
          success = true
          break
        end

        # If it's not an "unknown option" issue, no point retrying other variants.
        break unless stderr.to_s.include?('Option not found')
      end

      unless success
        last = tried.last
        raise Error,
              "ffmpeg failed (v360 unsupported/old build). Tried: #{tried.map { |t| t[:v360_extra] || 'none' }.join(' -> ')}. " \
              "Last error: #{last ? last[:stderr] : 'unknown error'}"
      end

      result = Tempfile.new(['immersive_equirect', '.mp4'])
      result.close
      FileUtils.cp(out_path, result.path)
      return result
    end
  end
end
