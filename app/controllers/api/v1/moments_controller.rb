# frozen_string_literal: true

require 'stringio'

module Api
  module V1
    class MomentsController < ApplicationController
      before_action :require_authentication!, except: [:thumbnail]
      before_action :set_moment, only: [:thumbnail]
      before_action :set_moment_for_download, only: [:download]
      before_action :authorize_moment_download!, only: [:download]
      before_action :set_owned_moment, only: [:show, :update]
      before_action :set_moment_for_destroy, only: [:destroy]
      before_action :authorize_moment_destroy!, only: [:destroy]

      MAX_STORIES_PER_USER = 5

      # POST /api/v1/moments/stories
      # Accepts either an image OR a video (max 30s) as a story.
      def stories
        image_file = params[:image]
        video_file = params[:video]

        if image_file.blank? && video_file.blank?
          api_error(message: 'Either image or video file is required for a story', status: :bad_request)
          return
        end

        if image_file.present? && video_file.present?
          api_error(message: 'Please upload either an image OR a video, not both', status: :bad_request)
          return
        end

        if video_file.present?
          duration = params[:duration_seconds].to_i
          if duration.positive? && duration > 30
            api_error(message: 'Video stories must be 30 seconds or less', status: :bad_request)
            return
          end
        end

        enforce_story_limit!

        moment = current_user.moments.build(
          venue_id: params[:venue_id],
          event_id: params[:event_id],
          audience: params[:audience].presence || 'public',
          disappearing_duration: params[:disappearing_duration].presence || '24h'
        )

        if image_file.present?
          moment.image.attach(image_file)
        elsif video_file.present?
          moment.video.attach(video_file)
        end

        if moment.save
          api_success(
            data: { story: moment_response(moment) },
            message: 'Story created successfully',
            status: :created
          )
        else
          api_validation_error(errors: moment.errors.full_messages)
        end
      end

      # POST /api/v1/moments/stories/dual_cam
      # multipart: back_video (main/fullscreen) + front_video (PiP top-right); merged to one 1080x1920 MP4 (max 30s each).
      def dual_cam_story
        back_file = params[:back_video].presence || params[:back].presence
        front_file = params[:front_video].presence || params[:front].presence

        if back_file.blank? || front_file.blank?
          api_error(
            message: 'Both back_video and front_video files are required (multipart field names: back_video, front_video)',
            status: :bad_request
          )
          return
        end

        unless dual_cam_multipart_upload?(back_file)
          api_error(
            message: 'back_video must be uploaded as multipart/form-data binary file data, not a local path or JSON string. ' \
                     'Use multipart encoding (e.g. Alamofire multipart, URLSession upload with body stream).',
            status: :bad_request
          )
          return
        end

        unless dual_cam_multipart_upload?(front_file)
          api_error(
            message: 'front_video must be uploaded as multipart/form-data binary file data, not a local path or JSON string.',
            status: :bad_request
          )
          return
        end

        if params[:back_duration_seconds].to_i > 30 ||
           params[:front_duration_seconds].to_i > 30
          api_error(message: 'Each camera clip must be 30 seconds or less', status: :bad_request)
          return
        end

        enforce_story_limit!

        merged = nil
        moment = current_user.moments.build(
          venue_id: params[:venue_id],
          event_id: params[:event_id],
          audience: params[:audience].presence || 'public',
          disappearing_duration: params[:disappearing_duration].presence || '24h'
        )

        begin
          merged = DualCameraVideoMergeService.merge_to_tempfile(back_file, front_file)
          # ActiveStorage may read the IO during moment.save, not during attach — a File block closes
          # the handle before save runs, causing IOError (closed stream). Buffer merged output instead.
          data = File.binread(merged.path)
          moment.video.attach(
            io: StringIO.new(data),
            filename: "dual_cam_#{SecureRandom.hex(8)}.mp4",
            content_type: 'video/mp4'
          )
        rescue DualCameraVideoMergeService::Error => e
          api_error(message: e.message, status: :unprocessable_content)
          return
        ensure
          merged&.unlink
        end

        if moment.save
          api_success(
            data: { story: moment_response(moment) },
            message: 'Dual camera story created successfully',
            status: :created
          )
        else
          api_validation_error(errors: moment.errors.full_messages)
        end
      end

      # POST /api/v1/moments/stories/immersive
      # Six synchronized cubemap-face MP4s → merged equirectangular 360° video (max 30s per face).
      # Multipart field names: front (required), right, back, left, top, bottom (optional; missing faces fall back to front).
      def immersive_story
        faces = immersive_face_params
        front = faces[:front]
        if front.blank?
          api_error(message: 'front face video is required (multipart field name: front)', status: :bad_request)
          return
        end

        # Keep only one immersive story per venue for this user (soft-delete older ones).
        if params[:venue_id].present?
          current_user.moments
                      .visible
                      .where(venue_id: params[:venue_id], projection: 'equirectangular')
                      .where.not(id: nil)
                      .find_each(&:soft_delete!)
        end

        present_faces = faces.select { |_k, v| v.present? }
        unless present_faces.values.all? { |f| dual_cam_multipart_upload?(f) }
          api_error(
            message: 'Each face must be uploaded as multipart binary video data, not a path or JSON string.',
            status: :bad_request
          )
          return
        end

        # Optional: "fake" immersive from a single normal camera video.
        # Default is NO-DISTORTION (blurred background + center-fit foreground).
        mode = params[:mode].to_s.presence || 'pad_blur_2to1'
        if mode.in?(%w[pad_blur_2to1 rectilinear_patch stretch_equirectangular]) && present_faces.keys == [:front]
          enforce_story_limit!
          merged = nil
          merged_io = nil
          moment = current_user.moments.build(
            venue_id: params[:venue_id],
            event_id: params[:event_id],
            audience: params[:audience].presence || 'public',
            disappearing_duration: params[:disappearing_duration].presence || 'none',
            projection: 'equirectangular'
          )

          begin
            if mode == 'pad_blur_2to1'
              blur = (params[:blur_sigma] || 20).to_f
              merged = PadBlurToEquirectangularVideoService.convert_to_tempfile(front, blur_sigma: blur)
            elsif mode == 'rectilinear_patch'
              yaw = (params[:yaw] || 0).to_f
              pitch = (params[:pitch] || 0).to_f
              h_fov = (params[:h_fov] || params[:fov] || 90).to_f
              v_fov = (params[:v_fov] || 60).to_f
              blur = (params[:blur_sigma] || 20).to_f
              merged = RectilinearPatchToEquirectangularVideoService.convert_to_tempfile(
                front,
                yaw: yaw,
                pitch: pitch,
                h_fov: h_fov,
                v_fov: v_fov,
                blur_sigma: blur
              )
            else
              merged = FlatToEquirectangularVideoService.convert_to_tempfile(front)
            end
            merged_io = File.open(merged.path, 'rb')
            moment.video.attach(
              io: merged_io,
              filename: "immersive_flat_#{SecureRandom.hex(8)}.mp4",
              content_type: 'video/mp4'
            )
            moment.save!
          rescue FlatToEquirectangularVideoService::Error => e
            api_error(message: e.message, status: :unprocessable_content)
            return
          rescue ActiveRecord::RecordInvalid => e
            api_validation_error(errors: e.record.errors.full_messages)
            return
          ensure
            merged_io&.close
            merged&.unlink
          end

          api_success(
            data: { story: moment_response(moment) },
            message: 'Immersive story created successfully',
            status: :created
          )
          return
        end

        # Allow uploading ONLY the front face. For any missing faces, reuse the front clip so
        # clients don't need to duplicate the same video 6 times.
        faces = faces.transform_values { |v| v.presence || front }

        if params[:duration_seconds].to_i > 30
          api_error(message: 'Immersive face videos must be 30 seconds or less each', status: :bad_request)
          return
        end

        enforce_story_limit!

        merged = nil
        merged_io = nil
        moment = current_user.moments.build(
          venue_id: params[:venue_id],
          event_id: params[:event_id],
          audience: params[:audience].presence || 'public',
          disappearing_duration: params[:disappearing_duration].presence || 'none',
          projection: 'equirectangular'
        )

        begin
          merged = CubemapToEquirectangularVideoService.convert_to_tempfile(faces)
          merged_io = File.open(merged.path, 'rb')
          moment.video.attach(
            io: merged_io,
            filename: "immersive_#{SecureRandom.hex(8)}.mp4",
            content_type: 'video/mp4'
          )
          moment.save!
        rescue CubemapToEquirectangularVideoService::Error, DualCameraVideoMergeService::Error => e
          api_error(message: e.message, status: :unprocessable_content)
          return
        rescue ActiveRecord::RecordInvalid => e
          api_validation_error(errors: e.record.errors.full_messages)
          return
        ensure
          merged_io&.close
          merged&.unlink
        end

        api_success(
          data: { story: moment_response(moment) },
          message: 'Immersive story created successfully',
          status: :created
        )
      end

      # GET /api/v1/moments/my_stories
      # Query: limit, offset, optional venue_id, event_id (filters apply together when both present)
      def my_stories
        limit = [params[:limit]&.to_i || 20, 100].min
        offset = params[:offset]&.to_i || 0

        scope = current_user.moments.for_feed.order(created_at: :desc)
        scope = scope.where(venue_id: params[:venue_id]) if params[:venue_id].present?
        scope = scope.where(event_id: params[:event_id]) if params[:event_id].present?
        total_count = scope.count
        stories = scope.limit(limit).offset(offset)

        api_success(
          data: {
            stories: stories.map { |m| moment_response(m) },
            pagination: {
              limit: limit,
              offset: offset,
              total_count: total_count,
              has_more: (offset + limit) < total_count
            }
          },
          status: :ok
        )
      end

      # GET /api/v1/moments/:id — owner only; non-deleted, non-expired story
      def show
        api_success(data: { story: moment_response(@moment) }, status: :ok)
      end

      # PATCH /api/v1/moments/:id — owner only; optional audience, disappearing_duration (recomputes expires_at when duration changes)
      def update
        if @moment.update(moment_update_params)
          api_success(
            data: { story: moment_response(@moment.reload) },
            message: 'Story updated successfully',
            status: :ok
          )
        else
          api_validation_error(errors: @moment.errors.full_messages)
        end
      end

      # DELETE /api/v1/moments/:id — owner only; soft-delete (same as platform story removal)
      def destroy
        @moment.soft_delete!
        api_success(message: 'Story removed', status: :ok, data: { id: @moment.id })
      end

      # GET /api/v1/moments/:id/thumbnail
      # Serves video thumbnail as JPEG (Content-Type: image/jpeg).
      # For image moments, redirects to the image. No auth required for public stories.
      def thumbnail
        if @moment.video.attached?
          preview = @moment.video.preview(resize_to_limit: [400, 400], format: :jpeg)
          preview.processed
          send_data preview.download,
                    type: 'image/jpeg',
                    disposition: 'inline',
                    filename: "thumbnail_#{@moment.id}.jpg"
        elsif @moment.image.attached?
          redirect_to url_for(@moment.image), allow_other_host: true
        else
          head :not_found
        end
      rescue ActiveStorage::FileNotFoundError, ActiveStorage::InvariableError,
             ActiveStorage::UnrepresentableError, ActiveStorage::UnpreviewableError,
             ActiveStorage::Preview::UnprocessedError, LoadError => _e
        head :not_found
      end

      # GET /api/v1/moments/:id/download
      # Watermarked copy ("vibes") for saving; requires auth; owner, public, or follower (when audience is followers).
      def download
        blob = if @moment.video.attached?
                 @moment.video.blob
               elsif @moment.image.attached?
                 @moment.image.blob
               else
                 head :not_found
                 return
               end

        if @moment.image.attached?
          data = MomentWatermarkService.image_watermarked_blob(blob)
          send_data data,
                    type: 'image/jpeg',
                    disposition: %(attachment; filename="vibes_story_#{@moment.id}.jpg")
        else
          data = MomentWatermarkService.video_watermarked_blob(blob)
          send_data data,
                    type: 'video/mp4',
                    disposition: %(attachment; filename="vibes_story_#{@moment.id}.mp4")
        end
      rescue MomentWatermarkService::WatermarkError => e
        Rails.logger.warn "[MomentWatermark] #{e.message}"
        api_error(message: e.message, status: :service_unavailable)
      rescue MiniMagick::Error => e
        Rails.logger.error "[MomentWatermark] #{e.class}: #{e.message}"
        api_error(message: 'Could not process image for download', status: :service_unavailable)
      end

      # GET /api/v1/moments/stories
      # Stories feed from self + users current_user follows.
      def stories_feed
        limit = [params[:limit]&.to_i || 20, 100].min
        offset = params[:offset]&.to_i || 0

        followed_ids = current_user.following.pluck(:id)
        user_ids = (followed_ids + [current_user.id]).uniq

        scope = Moment.for_feed.where(user_id: user_ids).order(created_at: :desc)
        total_count = scope.count
        stories = scope.limit(limit).offset(offset)

        api_success(
          data: {
            stories: stories.map { |m| moment_response(m, include_user: true) },
            pagination: {
              limit: limit,
              offset: offset,
              total_count: total_count,
              has_more: (offset + limit) < total_count
            }
          },
          status: :ok
        )
      end

      private

      def set_owned_moment
        @moment = current_user.moments.for_feed.find_by(id: params[:id])
        return if @moment

        api_error(message: 'Story not found', status: :not_found)
        return
      end

      def set_moment_for_destroy
        @moment = Moment.for_feed.find_by(id: params[:id])
        return if @moment

        api_error(message: 'Story not found', status: :not_found)
        nil
      end

      # Allow venue-side users to delete stories tied to their venue/event.
      # Owners can always delete their own stories (handled by this check too).
      def authorize_moment_destroy!
        return if current_user.role_admin?
        return if @moment.user_id == current_user.id

        venue_id =
          if @moment.venue_id.present?
            @moment.venue_id
          elsif @moment.event_id.present?
            @moment.event&.venue_id
          end

        if venue_id.present?
          venue = Venue.find_by(id: venue_id)
          if venue
            return if venue.owner_id == current_user.id
            return if venue.venue_staff.active.by_role('manager').exists?(user_id: current_user.id)
            return if venue.venue_pr_partnerships.active.exists?(user_id: current_user.id)
          end
        end

        api_error(message: 'Unauthorized', status: :forbidden)
        nil
      end

      def moment_update_params
        if params[:moment].present?
          params.require(:moment).permit(:audience, :disappearing_duration)
        else
          params.permit(:audience, :disappearing_duration)
        end
      end

      def immersive_face_params
        {
          front: params[:front].presence || params[:face_front].presence,
          right: params[:right].presence || params[:face_right].presence,
          back: params[:back].presence || params[:face_back].presence,
          left: params[:left].presence || params[:face_left].presence,
          top: params[:top].presence || params[:face_top].presence,
          bottom: params[:bottom].presence || params[:face_bottom].presence
        }
      end

      # True for Rack multipart file; false for JSON/plain strings (e.g. iOS sending local file paths).
      def dual_cam_multipart_upload?(file)
        return false if file.is_a?(String)
        return true if file.is_a?(ActionDispatch::Http::UploadedFile)
        file.respond_to?(:tempfile) && file.tempfile.present?
      end

      def set_moment
        @moment = Moment.find_by(id: params[:id])
        unless @moment
          head :not_found
          return
        end
      end

      def set_moment_for_download
        @moment = Moment.for_feed.find_by(id: params[:id])
        unless @moment
          head :not_found
          return
        end
      end

      def authorize_moment_download!
        return if @moment.user_id == current_user.id
        return if @moment.audience == 'public'
        return if @moment.audience == 'followers' && current_user.following?(@moment.user)

        head :forbidden
      end

      # Enforce max 5 active stories per user by deleting the oldest visible, non-expired one.
      def enforce_story_limit!
        scope = current_user.moments.for_feed.order(created_at: :asc)
        count = scope.count
        return if count < MAX_STORIES_PER_USER

        oldest = scope.first
        oldest&.soft_delete!
      end

      def moment_response(moment, include_user: false)
        type = moment.media_type
        url = if moment.video.attached?
                url_for(moment.video)
              elsif moment.image.attached?
                url_for(moment.image)
              else
                nil
              end

        thumbnail = if moment.video.attached?
                      # Use custom thumbnail endpoint to guarantee JPEG (Content-Type: image/jpeg)
                      api_v1_moment_thumbnail_url(moment)
                    elsif moment.image.attached?
                      url_for(moment.image)
                    else
                      nil
                    end

        data = {
          id: moment.id,
          type: type,
          projection: moment.projection,
          immersive: moment.immersive?,
          thumbnail: thumbnail.to_s,
          url: url.to_s,
          download_url: api_v1_moment_download_url(moment),
          audience: moment.audience,
          venue_id: moment.venue_id,
          event_id: moment.event_id,
          expires_at: moment.expires_at&.iso8601,
          created_at: moment.created_at.iso8601
        }

        # Legacy fields for backward compatibility
        data[:kind] = type
        data[:image_url] = moment.image.attached? ? url_for(moment.image) : nil
        data[:video_url] = moment.video.attached? ? url_for(moment.video) : nil

        if include_user
          data[:user] = {
            id: moment.user.id,
            name: moment.user.name,
            username: moment.user.username,
            avatar_url: moment.user.avatar_url
          }
        end

        data
      end
    end
  end
end

