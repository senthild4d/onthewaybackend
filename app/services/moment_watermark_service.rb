# frozen_string_literal: true

require 'mini_magick'

# Applies a visible "vibes" watermark for story/moment downloads.
# Images: ImageMagick via MiniMagick (requires +imagemagick+ on the server).
# Video: ffmpeg drawtext (requires +ffmpeg+ and a TTF font; see +FFMPEG_WATERMARK_FONT+).
class MomentWatermarkService
  WATERMARK_TEXT = 'vibes'

  class WatermarkError < StandardError; end

  def self.image_watermarked_blob(blob)
    raise WatermarkError, 'ImageMagick not available' unless imagemagick_available?

    blob.open do |file|
      img = MiniMagick::Image.open(file.path)
      img.auto_orient
      size = (img.width * 0.045).to_i.clamp(20, 84)
      img.combine_options do |c|
        c.gravity 'South'
        c.pointsize size
        c.fill 'rgba(255,255,255,0.92)'
        c.stroke 'rgba(0,0,0,0.45)'
        c.strokewidth 2
        c.annotate '+0+24', WATERMARK_TEXT
      end
      img.format 'jpg'
      img.quality '88'
      img.to_blob
    end
  end

  def self.video_watermarked_blob(blob)
    raise WatermarkError, 'ffmpeg not available' unless ffmpeg_available?

    ext = File.extname(blob.filename.to_s)
    ext = '.mp4' if ext.blank?

    Dir.mktmpdir('moment_wm') do |dir|
      infile = File.join(dir, "in#{ext}")
      outfile = File.join(dir, 'out.mp4')
      File.binwrite(infile, blob.download)

      font = watermark_font_path
      vf = if font
             "drawtext=fontfile=#{escape_filter_path(font)}:text='#{WATERMARK_TEXT}':fontcolor=white@0.92:fontsize=h/18:borderw=2:bordercolor=black@0.55:x=(w-text_w)/2:y=h-th-16"
           else
             "drawtext=text='#{WATERMARK_TEXT}':fontcolor=white@0.92:fontsize=24:borderw=2:bordercolor=black@0.55:x=(w-text_w)/2:y=h-th-16"
           end

      ok = system(
        'ffmpeg', '-y', '-hide_banner', '-loglevel', 'error',
        '-i', infile,
        '-vf', vf,
        '-c:v', 'libx264', '-preset', 'fast', '-crf', '23',
        '-c:a', 'copy',
        outfile
      )

      unless ok && File.exist?(outfile) && File.size(outfile).positive?
        ok = system(
          'ffmpeg', '-y', '-hide_banner', '-loglevel', 'error',
          '-i', infile,
          '-vf', vf,
          '-c:v', 'libx264', '-preset', 'fast', '-crf', '23',
          '-an',
          outfile
        )
      end

      raise WatermarkError, 'ffmpeg failed to watermark video' unless ok && File.exist?(outfile) && File.size(outfile).positive?

      File.binread(outfile)
    end
  end

  def self.imagemagick_available?
    @imagemagick_available ||= system('magick', '-version', out: File::NULL, err: File::NULL) ||
                               system('convert', '-version', out: File::NULL, err: File::NULL)
  end

  def self.ffmpeg_available?
    @ffmpeg_available ||= system('ffmpeg', '-version', out: File::NULL, err: File::NULL)
  end

  def self.watermark_font_path
    return ENV['FFMPEG_WATERMARK_FONT'] if ENV['FFMPEG_WATERMARK_FONT'].present? && File.exist?(ENV['FFMPEG_WATERMARK_FONT'])

    %w[
      /usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf
      /usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf
    ].find { |p| File.exist?(p) }
  end

  def self.escape_filter_path(path)
    path.gsub('\\', '\\\\').gsub(':', '\\:').gsub("'", "\\'")
  end
end
