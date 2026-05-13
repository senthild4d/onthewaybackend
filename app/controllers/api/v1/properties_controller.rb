module Api
  module V1
    class PropertiesController < ApplicationController
      before_action :require_authentication!, except: [:index, :show, :form_options, :search]
      before_action :set_property, only: [:show, :update, :destroy, :submit, :approve, :reject, :upload_images, :upload_video, :remove_image, :remove_video]
      before_action :authorize_owner_or_staff!, only: [:update, :destroy, :upload_images, :upload_video, :remove_image, :remove_video, :submit]
      before_action :authorize_staff!, only: [:approve, :reject]
      before_action :authorize_owner_or_admin!, only: [:mark_sold, :archive, :unarchive]

      # GET /api/v1/properties
      def index
        scope = Property.includes(images_attachments: :blob, video_attachment: :blob, owner: { profile_picture_attachment: :blob })

        # Public users only see approved listings. Owners can see their own drafts too.
        if current_user&.role_owner?
          scope = scope.where('approval_status = ? OR owner_id = ?', 'approved', current_user.id)
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
        current_year = Date.current.year

        options = {
          currencies: [
            { value: 'USD', label: 'US Dollar', symbol: '$' },
            { value: 'EUR', label: 'Euro', symbol: '€' },
            { value: 'GBP', label: 'British Pound', symbol: '£' },
            { value: 'AED', label: 'UAE Dirham', symbol: 'د.إ' },
            { value: 'SAR', label: 'Saudi Riyal', symbol: '﷼' },
            { value: 'INR', label: 'Indian Rupee', symbol: '₹' },
            { value: 'PKR', label: 'Pakistani Rupee', symbol: '₨' },
            { value: 'CAD', label: 'Canadian Dollar', symbol: 'C$' },
            { value: 'AUD', label: 'Australian Dollar', symbol: 'A$' },
            { value: 'SGD', label: 'Singapore Dollar', symbol: 'S$' },
            { value: 'QAR', label: 'Qatari Riyal', symbol: 'ر.ق' },
            { value: 'KWD', label: 'Kuwaiti Dinar', symbol: 'د.ك' },
            { value: 'BHD', label: 'Bahraini Dinar', symbol: '.د.ب' },
            { value: 'OMR', label: 'Omani Rial', symbol: 'ر.ع.' },
            { value: 'EGP', label: 'Egyptian Pound', symbol: 'E£' },
            { value: 'TRY', label: 'Turkish Lira', symbol: '₺' }
          ],
          purposes: [
            { value: 'sale', label: 'Sale' },
            { value: 'rent', label: 'Rent' }
          ],
          property_types: [
            { value: 'apartment', label: 'Apartment' },
            { value: 'villa', label: 'Villa' },
            { value: 'townhouse', label: 'Townhouse' },
            { value: 'penthouse', label: 'Penthouse' },
            { value: 'studio', label: 'Studio' },
            { value: 'duplex', label: 'Duplex' },
            { value: 'land', label: 'Land' },
            { value: 'office', label: 'Office' },
            { value: 'shop', label: 'Shop' },
            { value: 'warehouse', label: 'Warehouse' },
            { value: 'building', label: 'Building' },
            { value: 'farm', label: 'Farm' },
            { value: 'other', label: 'Other' }
          ],
          features: [
            { value: 'balcony', label: 'Balcony' },
            { value: 'garden', label: 'Garden' },
            { value: 'pool', label: 'Swimming Pool' },
            { value: 'gym', label: 'Gym' },
            { value: 'elevator', label: 'Elevator' },
            { value: 'security', label: '24/7 Security' },
            { value: 'parking', label: 'Parking' },
            { value: 'central_ac', label: 'Central A/C' },
            { value: 'maid_room', label: "Maid's Room" },
            { value: 'storage', label: 'Storage Room' },
            { value: 'pets_allowed', label: 'Pets Allowed' },
            { value: 'furnished', label: 'Furnished' },
            { value: 'sea_view', label: 'Sea View' },
            { value: 'city_view', label: 'City View' }
          ],
          furnished_options: [
            { value: 'furnished', label: 'Furnished' },
            { value: 'unfurnished', label: 'Unfurnished' },
            { value: 'semi_furnished', label: 'Semi-Furnished' }
          ],
          bedroom_options: [
            { value: '0', label: 'Studio' },
            { value: '1', label: '1 Bedroom' },
            { value: '2', label: '2 Bedrooms' },
            { value: '3', label: '3 Bedrooms' },
            { value: '4', label: '4 Bedrooms' },
            { value: '5', label: '5 Bedrooms' },
            { value: '6', label: '6 Bedrooms' },
            { value: '7', label: '7 Bedrooms' },
            { value: '8+', label: '8+ Bedrooms' }
          ],
          bathroom_options: [
            { value: '1', label: '1 Bathroom' },
            { value: '2', label: '2 Bathrooms' },
            { value: '3', label: '3 Bathrooms' },
            { value: '4', label: '4 Bathrooms' },
            { value: '5', label: '5 Bathrooms' },
            { value: '6', label: '6 Bathrooms' },
            { value: '7+', label: '7+ Bathrooms' }
          ],
          parking_options: [
            { value: '0', label: 'No Parking' },
            { value: '1', label: '1 Space' },
            { value: '2', label: '2 Spaces' },
            { value: '3', label: '3 Spaces' },
            { value: '4', label: '4 Spaces' },
            { value: '5+', label: '5+ Spaces' }
          ],
          floor_options: [
            { value: '-2', label: 'Basement 2' },
            { value: '-1', label: 'Basement 1' },
            { value: '0', label: 'Ground Floor' },
            { value: '1', label: '1st Floor' },
            { value: '2', label: '2nd Floor' },
            { value: '3', label: '3rd Floor' },
            { value: '4', label: '4th Floor' },
            { value: '5', label: '5th Floor' },
            { value: '6', label: '6th Floor' },
            { value: '7', label: '7th Floor' },
            { value: '8', label: '8th Floor' },
            { value: '9', label: '9th Floor' },
            { value: '10', label: '10th Floor' },
            { value: 'penthouse', label: 'Penthouse' }
          ],
          area_units: [
            { value: 'sqft', label: 'Square Feet (sq ft)' },
            { value: 'sqm', label: 'Square Meters (sq m)' }
          ],
          year_built_range: {
            min: 1900,
            max: current_year,
            default: current_year
          },
          price_ranges: {
            sale: [
              { min: 0, max: 100_000, label: 'Under 100K' },
              { min: 100_000, max: 250_000, label: '100K - 250K' },
              { min: 250_000, max: 500_000, label: '250K - 500K' },
              { min: 500_000, max: 1_000_000, label: '500K - 1M' },
              { min: 1_000_000, max: 2_500_000, label: '1M - 2.5M' },
              { min: 2_500_000, max: 5_000_000, label: '2.5M - 5M' },
              { min: 5_000_000, max: 10_000_000, label: '5M - 10M' },
              { min: 10_000_000, max: nil, label: 'Above 10M' }
            ],
            rent: [
              { min: 0, max: 500, label: 'Under 500' },
              { min: 500, max: 1_000, label: '500 - 1K' },
              { min: 1_000, max: 2_500, label: '1K - 2.5K' },
              { min: 2_500, max: 5_000, label: '2.5K - 5K' },
              { min: 5_000, max: 10_000, label: '5K - 10K' },
              { min: 10_000, max: 25_000, label: '10K - 25K' },
              { min: 25_000, max: nil, label: 'Above 25K' }
            ]
          },
          listing_statuses: [
            { value: 'active', label: 'Active' },
            { value: 'sold', label: 'Sold' },
            { value: 'archived', label: 'Archived' }
          ],
          approval_statuses: [
            { value: 'draft', label: 'Draft' },
            { value: 'pending_review', label: 'Pending Review' },
            { value: 'approved', label: 'Approved' },
            { value: 'rejected', label: 'Rejected' },
            { value: 'archived', label: 'Archived' }
          ],
          sort_options: [
            { value: 'newest', label: 'Newest First' },
            { value: 'oldest', label: 'Oldest First' },
            { value: 'price_asc', label: 'Price: Low to High' },
            { value: 'price_desc', label: 'Price: High to Low' }
          ],
          countries: [
            { value: 'AE', label: 'United Arab Emirates', flag: '🇦🇪' },
            { value: 'SA', label: 'Saudi Arabia', flag: '🇸🇦' },
            { value: 'IN', label: 'India', flag: '🇮🇳' },
            { value: 'PK', label: 'Pakistan', flag: '🇵🇰' },
            { value: 'US', label: 'United States', flag: '🇺🇸' },
            { value: 'GB', label: 'United Kingdom', flag: '🇬🇧' },
            { value: 'CA', label: 'Canada', flag: '🇨🇦' },
            { value: 'AU', label: 'Australia', flag: '🇦🇺' },
            { value: 'SG', label: 'Singapore', flag: '🇸🇬' },
            { value: 'QA', label: 'Qatar', flag: '🇶🇦' },
            { value: 'KW', label: 'Kuwait', flag: '🇰🇼' },
            { value: 'BH', label: 'Bahrain', flag: '🇧🇭' },
            { value: 'OM', label: 'Oman', flag: '🇴🇲' },
            { value: 'EG', label: 'Egypt', flag: '🇪🇬' },
            { value: 'TR', label: 'Turkey', flag: '🇹🇷' }
          ],
          limits: {
            max_images: 20,
            max_image_size_mb: 10,
            max_video_size_mb: 200,
            max_title_length: 255
          }
        }

        api_success(data: options, status: :ok)
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
          api_success(data: { property: property_response(property, detailed: true) }, message: 'Property created', status: :created)
        else
          api_validation_error(errors: property.errors.full_messages)
        end
      end

      # PATCH /api/v1/properties/:id
      def update
        if @property.update(property_params)
          api_success(data: { property: property_response(@property.reload, detailed: true) }, message: 'Property updated', status: :ok)
        else
          api_validation_error(errors: @property.errors.full_messages)
        end
      end

      # DELETE /api/v1/properties/:id
      def destroy
        @property.destroy
        api_success(message: 'Property deleted', status: :ok, data: { id: @property.id })
      end

      # POST /api/v1/properties/:id/submit
      def submit
        if @property.approval_status_draft? || @property.approval_status_rejected?
          @property.submit_for_review!
          api_success(data: { property: property_response(@property.reload, detailed: true) }, message: 'Submitted for review', status: :ok)
        else
          api_error(message: 'Property cannot be submitted in its current state', status: :bad_request)
        end
      end

      # POST /api/v1/properties/:id/approve
      def approve
        @property.approve!(by: current_user)
        notify_property_owner(@property, 'Property Approved', "Your property \"#{@property.title}\" has been approved.", 'property_approved')
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
        api_success(data: { property: property_response(@property.reload, detailed: true) }, message: 'Property rejected', status: :ok)
      end

      # POST /api/v1/properties/:id/mark_sold
      def mark_sold
        @property.mark_sold!(by: current_user)
        api_success(data: { property: property_response(@property.reload, detailed: true) }, message: 'Property marked as sold', status: :ok)
      end

      # POST /api/v1/properties/:id/archive
      def archive
        @property.archive!(by: current_user)
        api_success(data: { property: property_response(@property.reload, detailed: true) }, message: 'Property archived', status: :ok)
      end

      # POST /api/v1/properties/:id/unarchive
      def unarchive
        @property.unarchive!
        api_success(data: { property: property_response(@property.reload, detailed: true) }, message: 'Property unarchived', status: :ok)
      end

      # POST /api/v1/properties/:id/images
      def upload_images
        attach_images(@property)
        if @property.save
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
        api_success(data: { property: property_response(@property.reload, detailed: true) }, message: 'Image removed', status: :ok)
      end

      # POST /api/v1/properties/:id/video
      def upload_video
        attach_video(@property, replace: true)
        if @property.save
          api_success(data: { property: property_response(@property.reload, detailed: true) }, message: 'Video uploaded', status: :ok)
        else
          api_validation_error(errors: @property.errors.full_messages)
        end
      end

      # DELETE /api/v1/properties/:id/video
      def remove_video
        @property.video.purge if @property.video.attached?
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
        unless @property
          api_error(message: 'Property not found', status: :not_found)
          return
        end
      end

      def authorize_owner_or_staff!
        return if current_user&.admin?
        return if current_user&.role_owner? && @property.owner_id == current_user.id
        api_error(message: 'Unauthorized', status: :forbidden)
      end

      def authorize_staff!
        return if current_user&.admin?
        api_error(message: 'Unauthorized', status: :forbidden)
      end

      def authorize_owner_or_admin!
        return if current_user&.admin?
        return if current_user&.role_owner? && @property.owner_id == current_user.id
        api_error(message: 'Unauthorized', status: :forbidden)
      end

      def can_view_property?(property)
        return true if property.approval_status_approved?
        return false if current_user.nil?
        return true if current_user.admin?
        current_user.role_owner? && property.owner_id == current_user.id
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
          features: {}
        )
      end

      def attach_images(property)
        imgs = params[:images]
        imgs = [imgs].compact unless imgs.is_a?(Array)
        imgs.each { |img| property.images.attach(img) } if imgs.present?
      end

      def attach_video(property, replace: false)
        vid = params[:video]
        return unless vid.present?
        property.video.purge if replace && property.video.attached?
        property.video.attach(vid)
      end

      def property_response(property, detailed: false)
        images = property.images.map { |img| attachment_url(img) }
        video_url = attachment_url(property.video)

        data = {
          id: property.id,
          title: property.title,
          description: property.description,
          property_type: property.property_type,
          purpose: property.purpose,
          bedrooms: property.bedrooms,
          bathrooms: property.bathrooms,
          area_sqft: property.area_sqft,
          area_sqm: property.area_sqm,
          price: property.price,
          currency: property.currency,
          approval_status: property.approval_status,
          listing_status: property.listing_status,
          sold_at: property.sold_at&.iso8601,
          archived_at: property.archived_at&.iso8601,
          features: property.features || {},
          submitted_at: property.submitted_at&.iso8601,
          approved_at: property.approved_at&.iso8601,
          rejected_at: property.rejected_at&.iso8601,
          rejection_reason: property.rejection_reason,
          address: {
            address1: property.address1,
            address2: property.address2,
            city: property.city,
            region: property.region,
            postal_code: property.postal_code,
            country: property.country,
            full_address: property.full_address
          },
          coordinates: property.coordinates? ? { latitude: property.latitude.to_f, longitude: property.longitude.to_f } : nil,
          images: images,
          video: video_url
        }

        if detailed
          data[:owner] = {
            id: property.owner_id,
            name: property.owner&.name
          }
        end

        data
      end
    end
  end
end

