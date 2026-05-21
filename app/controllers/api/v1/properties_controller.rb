module Api
  module V1
    class PropertiesController < ApplicationController
      include PropertySerializable

      before_action :require_authentication!, except: [:index, :show, :form_options, :filter_options, :search]
      before_action :set_property, only: [:show, :update, :destroy, :submit, :approve, :reject, :mark_sold, :archive, :unarchive, :upload_images, :upload_video, :upload_360_video, :remove_image, :remove_video]
      before_action :authorize_owner_or_staff!, only: [:update, :destroy, :upload_images, :upload_video, :upload_360_video, :remove_image, :remove_video, :submit]
      before_action :authorize_staff!, only: [:approve, :reject]
      before_action :authorize_owner_or_admin!, only: [:mark_sold, :archive, :unarchive]

      # GET /api/v1/properties
      def index
        scope = Property.includes(images_attachments: :blob, video_attachment: :blob, owner: { profile_picture_attachment: :blob })

        # Public users only see approved listings. Owners can see their own drafts too.
        if current_user&.role_owner?
          scope = scope.where('owner_id = ?', current_user.id)
        elsif current_user&.admin?
          # staff sees all
        else
          scope = scope.visible_to_public
        end

        scope = scope.where(approval_status: Array(params[:status])) if params[:status].present? && current_user&.admin?
        scope = scope.where(country: params[:country]) if params[:country].present?
        scope = scope.where(region: params[:region]) if params[:region].present?
        scope = scope.where(city: params[:city]) if params[:city].present?
        scope = scope.where(purpose: params[:purpose]) if params[:purpose].present?
        scope = scope.where(property_type: Array(params[:property_type])) if params[:property_type].present?

        if params[:listing_status].present? && current_user&.admin?
          scope = scope.where(listing_status: Array(params[:listing_status]))
        end

        if params[:min_price].present?
          scope = scope.where('price >= ?', params[:min_price].to_d)
        end
        if params[:max_price].present?
          scope = scope.where('price <= ?', params[:max_price].to_d)
        end

        if params[:min_bedrooms].present?
          scope = scope.where('bedrooms >= ?', params[:min_bedrooms].to_i)
        end
        if params[:max_bedrooms].present?
          scope = scope.where('bedrooms <= ?', params[:max_bedrooms].to_i)
        end

        if params[:min_bathrooms].present?
          scope = scope.where('bathrooms >= ?', params[:min_bathrooms].to_i)
        end
        if params[:max_bathrooms].present?
          scope = scope.where('bathrooms <= ?', params[:max_bathrooms].to_i)
        end

        if params[:min_area_sqm].present?
          scope = scope.where('area_sqm >= ?', params[:min_area_sqm].to_d)
        end
        if params[:max_area_sqm].present?
          scope = scope.where('area_sqm <= ?', params[:max_area_sqm].to_d)
        end

        # Feature filters: features[]=elevator&features[]=balcony
        if params[:features].present?
          keys = Array(params[:features]).map(&:to_s).reject(&:blank?)
          keys.each do |k|
            scope = scope.where("features ->> ? = 'true'", k)
          end
        end

        # Full-text search across multiple fields
        if params[:search].present? || params[:q].present?
          term = (params[:search] || params[:q]).to_s.strip
          if term.present?
            q = "%#{term}%"
            scope = scope.where(
              'title ILIKE ? OR description ILIKE ? OR city ILIKE ? OR region ILIKE ? OR country ILIKE ? OR address1 ILIKE ? OR address2 ILIKE ? OR postal_code ILIKE ?',
              q, q, q, q, q, q, q, q
            )
          end
        end

        # bounds filter
        if params[:north].present? && params[:south].present? && params[:east].present? && params[:west].present?
          scope = scope.where(
            'latitude >= ? AND latitude <= ? AND longitude >= ? AND longitude <= ?',
            params[:south].to_f, params[:north].to_f, params[:west].to_f, params[:east].to_f
          )
        end

        sorted = case params[:sort_by].to_s
                 when 'price_asc' then scope.order(Arel.sql('price ASC NULLS LAST'), created_at: :desc)
                 when 'price_desc' then scope.order(Arel.sql('price DESC NULLS LAST'), created_at: :desc)
                 when 'oldest' then scope.order(created_at: :asc)
                 when 'newest' then scope.order(created_at: :desc)
                 else scope.order(created_at: :desc)
                 end

        page, per_page, offset = pagination_params(default_per_page: 20, max_per_page: 100)
        total_count = sorted.count
        total_pages = (total_count.to_f / per_page).ceil
        properties = sorted.limit(per_page).offset(offset)
        preload_favorite_property_ids!(properties)

        api_success(
          data: {
            properties: properties.map { |p| property_response(p) },
            pagination: {
              page: page,
              per_page: per_page,
              total_count: total_count,
              total_pages: total_pages,
              has_next_page: page < total_pages,
              has_prev_page: page > 1
            }
          },
          status: :ok
        )
      end

      # GET /api/v1/properties/search?q=keyword
      # Dedicated search endpoint with suggestions
      def search
        term = (params[:q] || params[:search] || params[:query]).to_s.strip
        if term.blank?
          api_error(message: 'Search query (q) is required', status: :bad_request)
          return
        end

        scope = Property.includes(images_attachments: :blob, video_attachment: :blob)

        if current_user&.role_owner?
          scope = scope.where('approval_status = ? OR owner_id = ?', 'approved', current_user.id)
        elsif current_user&.admin?
          # all
        else
          scope = scope.visible_to_public
        end

        q = "%#{term}%"
        scope = scope.where(
          'title ILIKE ? OR description ILIKE ? OR city ILIKE ? OR region ILIKE ? OR country ILIKE ? OR address1 ILIKE ? OR address2 ILIKE ? OR postal_code ILIKE ? OR property_type ILIKE ?',
          q, q, q, q, q, q, q, q, q
        )

        page, per_page, offset = pagination_params(default_per_page: 20, max_per_page: 100)
        total_count = scope.count
        total_pages = (total_count.to_f / per_page).ceil
        results = scope.order(created_at: :desc).limit(per_page).offset(offset)
        preload_favorite_property_ids!(results)

        # Get suggestions for cities and property types matching the term
        suggestions = {
          cities: Property.where('city ILIKE ?', q).distinct.limit(10).pluck(:city).compact,
          regions: Property.where('region ILIKE ?', q).distinct.limit(10).pluck(:region).compact,
          property_types: Property.where('property_type ILIKE ?', q).distinct.limit(10).pluck(:property_type).compact
        }

        api_success(
          data: {
            query: term,
            properties: results.map { |p| property_response(p) },
            suggestions: suggestions,
            pagination: {
              page: page,
              per_page: per_page,
              total_count: total_count,
              total_pages: total_pages,
              has_next_page: page < total_pages,
              has_prev_page: page > 1
            }
          },
          status: :ok
        )
      end

      # GET /api/v1/properties/form_options
      def form_options
        api_success(data: PropertyOptions.form_options, status: :ok)
      end

      # GET /api/v1/properties/filter_options
      def filter_options
        api_success(
          data: PropertyOptions.filter_options(admin: current_user&.admin?),
          status: :ok
        )
      end

      # GET /api/v1/properties/:id
      def show
        unless can_view_property?(@property)
          api_error(message: 'Property not found', status: :not_found)
          return
        end

        api_success(data: { property: property_response(@property, detailed: true) }, status: :ok)
      end

      # POST /api/v1/properties
      def create
        require_owner!
        property = Property.new(property_params.merge(owner_id: current_user.id))

        attach_images(property)
        attach_video(property)

        if property.save
          PropertyRealtimeService.property_updated(property, action: 'created', actor: current_user)
          api_success(data: { property: property_response(property, detailed: true) }, message: 'Property created', status: :created)
        else
          api_validation_error(errors: property.errors.full_messages)
        end
      end

      # PATCH /api/v1/properties/:id
      def update
        if @property.update(property_params)
          PropertyRealtimeService.property_updated(@property.reload, action: 'updated', actor: current_user)
          api_success(data: { property: property_response(@property.reload, detailed: true) }, message: 'Property updated', status: :ok)
        else
          api_validation_error(errors: @property.errors.full_messages)
        end
      end

      # DELETE /api/v1/properties/:id
      def destroy
        PropertyRealtimeService.property_updated(@property, action: 'deleted', actor: current_user)
        @property.destroy
        api_success(message: 'Property deleted', status: :ok, data: { id: @property.id })
      end

      # POST /api/v1/properties/:id/submit
      def submit
        if @property.approval_status_draft? || @property.approval_status_rejected?
          @property.submit_for_review!
          PropertyRealtimeService.property_updated(@property.reload, action: 'submitted', actor: current_user)
          api_success(data: { property: property_response(@property.reload, detailed: true) }, message: 'Submitted for review', status: :ok)
        else
          api_error(message: 'Property cannot be submitted in its current state', status: :bad_request)
        end
      end

      # POST /api/v1/properties/:id/approve
      def approve
        @property.approve!(by: current_user)
        notify_property_owner(@property, 'Property Approved', "Your property \"#{@property.title}\" has been approved.", 'property_approved')
        PropertyRealtimeService.property_updated(@property.reload, action: 'approved', actor: current_user)
        api_success(data: { property: property_response(@property.reload, detailed: true) }, message: 'Property approved', status: :ok)
      end

      # POST /api/v1/properties/:id/reject
      def reject
        reason = params[:reason].to_s
        if reason.blank?
          api_error(message: 'reason is required', status: :bad_request)
          return
        end

        @property.reject!(by: current_user, reason: reason)
        notify_property_owner(@property, 'Property Rejected', "Your property \"#{@property.title}\" was rejected. Reason: #{reason}", 'property_rejected')
        PropertyRealtimeService.property_updated(@property.reload, action: 'rejected', actor: current_user)
        api_success(data: { property: property_response(@property.reload, detailed: true) }, message: 'Property rejected', status: :ok)
      end

      # POST /api/v1/properties/:id/mark_sold
      def mark_sold
        @property.mark_sold!(by: current_user)
        PropertyRealtimeService.property_updated(@property.reload, action: 'sold', actor: current_user)
        api_success(data: { property: property_response(@property.reload, detailed: true) }, message: 'Property marked as sold', status: :ok)
      end

      # POST /api/v1/properties/:id/archive
      def archive
        @property.archive!(by: current_user)
        PropertyRealtimeService.property_updated(@property.reload, action: 'archived', actor: current_user)
        api_success(data: { property: property_response(@property.reload, detailed: true) }, message: 'Property archived', status: :ok)
      end

      # POST /api/v1/properties/:id/unarchive
      def unarchive
        @property.unarchive!
        PropertyRealtimeService.property_updated(@property.reload, action: 'unarchived', actor: current_user)
        api_success(data: { property: property_response(@property.reload, detailed: true) }, message: 'Property unarchived', status: :ok)
      end

      # POST /api/v1/properties/:id/images
      def upload_images
        attach_images(@property)
        if @property.save
          PropertyRealtimeService.property_updated(@property.reload, action: 'images_uploaded', actor: current_user)
          api_success(data: { property: property_response(@property.reload, detailed: true) }, message: 'Images uploaded', status: :ok)
        else
          api_validation_error(errors: @property.errors.full_messages)
        end
      end

      # DELETE /api/v1/properties/:id/images/:image_id
      def remove_image
        img = @property.images.attachments.find_by(id: params[:image_id])
        unless img
          api_error(message: 'Image not found', status: :not_found)
          return
        end
        img.purge
        PropertyRealtimeService.property_updated(@property.reload, action: 'image_removed', actor: current_user)
        api_success(data: { property: property_response(@property.reload, detailed: true) }, message: 'Image removed', status: :ok)
      end

      # POST /api/v1/properties/:id/video
      def upload_video
        attach_video(@property, replace: true)
        if @property.save
          PropertyRealtimeService.property_updated(@property.reload, action: 'video_uploaded', actor: current_user)
          api_success(data: { property: property_response(@property.reload, detailed: true) }, message: 'Video uploaded', status: :ok)
        else
          api_validation_error(errors: @property.errors.full_messages)
        end
      end

      # POST /api/v1/properties/:id/360_video
      def upload_360_video
        unless params[:video].present?
          api_error(message: 'video is required', status: :bad_request)
          return
        end

        attach_video(@property, replace: true, projection: 'equirectangular')
        if @property.save
          PropertyRealtimeService.property_updated(@property.reload, action: 'video_360_uploaded', actor: current_user)
          api_success(data: { property: property_response(@property.reload, detailed: true) }, message: '360 video uploaded', status: :ok)
        else
          api_validation_error(errors: @property.errors.full_messages)
        end
      end

      # DELETE /api/v1/properties/:id/video
      def remove_video
        @property.video.purge if @property.video.attached?
        PropertyRealtimeService.property_updated(@property.reload, action: 'video_removed', actor: current_user)
        api_success(data: { property: property_response(@property.reload, detailed: true) }, message: 'Video removed', status: :ok)
      end

      private

      def notify_property_owner(property, title, body, notification_type)
        return unless property.owner
        NotificationService.send_to_user(
          property.owner,
          title: title,
          body: body,
          notification_type: notification_type,
          data: { property_id: property.id.to_s },
          related: property
        )
      rescue => e
        Rails.logger.error "Failed to notify owner: #{e.message}"
      end

      def require_owner!
        return if current_user&.role_owner?
        api_error(message: 'Only owners can create properties', status: :forbidden)
      end

      def set_property
        @property = Property.find_by(id: params[:id])
        return if @property

        api_error(message: 'Property not found', status: :not_found)
        false
      end

      def authorize_owner_or_staff!
        return if current_user&.admin?
        return if current_user_owns_property?

        api_error(message: 'You can only manage your own properties', status: :forbidden)
        false
      end

      def authorize_staff!
        return if current_user&.admin?

        api_error(message: 'Only administrators can perform this action', status: :forbidden)
        false
      end

      def authorize_owner_or_admin!
        return if current_user&.admin?
        return if current_user_owns_property?

        api_error(message: 'You can only manage your own properties', status: :forbidden)
        false
      end

      def current_user_owns_property?
        current_user&.owns_property?(@property)
      end

      def can_view_property?(property)
        return true if property.approval_status_approved?
        return false if current_user.nil?
        return true if current_user.admin?
        current_user.owns_property?(property)
      end

      def property_params
        params.require(:property).permit(
          :title,
          :description,
          :property_type,
          :purpose,
          :bedrooms,
          :bathrooms,
          :area_sqft,
          :area_sqm,
          :address1,
          :address2,
          :city,
          :region,
          :postal_code,
          :country,
          :latitude,
          :longitude,
          :price,
          :currency,
          :year_built,
          :floor,
          :total_floors,
          :furnished,
          :parking_spaces,
          :video_projection,
          features: {}
        )
      end

      def attach_images(property)
        imgs = params[:images]
        imgs = [imgs].compact unless imgs.is_a?(Array)
        imgs.each { |img| property.images.attach(img) } if imgs.present?
      end

      def attach_video(property, replace: false, projection: nil)
        vid = params[:video]
        return unless vid.present?

        projection ||= video_projection_param
        property.video_projection = projection if projection.present?

        property.video.purge if replace && property.video.attached?
        property.video.attach(vid)
      end

      def video_projection_param
        value = params[:video_projection].presence || params.dig(:property, :video_projection).presence || params[:projection].presence
        return value if value.present?

        if ActiveModel::Type::Boolean.new.cast(params[:is_360_video] || params[:is_360] || params[:has_360_view])
          'equirectangular'
        end
      end
    end
  end
end

