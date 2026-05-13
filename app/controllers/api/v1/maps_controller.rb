module Api
  module V1
    class MapsController < ApplicationController
      before_action :require_authentication!, except: [:index, :filter_options]

      # GET /api/v1/maps
      def index
        properties = fetch_properties
        properties_array = properties.is_a?(Array) ? properties : properties.to_a
        items_for_bounds = properties_array

        map_data = {
          properties: properties_array.map { |p| map_property_response(p) }.compact,
          bounds: calculate_bounds(items_for_bounds),
          metadata: {
            properties_count: properties_array.count,
            total_markers: properties_array.count
          }
        }

        api_success(
          data: map_data,
          status: :ok
        )
      end

      # GET /api/v1/maps/filter_options
      def filter_options
        # Get available filter options for the map view
        options = {
          approval_statuses: [
            { value: 'approved', label: 'Approved' },
            { value: 'pending_review', label: 'Pending review' },
            { value: 'draft', label: 'Draft' },
            { value: 'rejected', label: 'Rejected' }
          ],
          listing_statuses: [
            { value: 'active', label: 'Active' },
            { value: 'sold', label: 'Sold' },
            { value: 'archived', label: 'Archived' }
          ],
          purposes: [
            { value: 'sale', label: 'Sale' },
            { value: 'rent', label: 'Rent' }
          ],
          radius_options: [
            { value: 1, label: '1 km' },
            { value: 5, label: '5 km' },
            { value: 10, label: '10 km' },
            { value: 25, label: '25 km' },
            { value: 50, label: '50 km' },
            { value: 100, label: '100 km' }
          ],
          sort_options: [
            { value: 'distance', label: 'Distance' },
            { value: 'newest', label: 'Newest' },
            { value: 'price_asc', label: 'Price (low to high)' },
            { value: 'price_desc', label: 'Price (high to low)' }
          ]
        }

        api_success(
          data: options,
          status: :ok
        )
      end

      private

      def fetch_properties
        scope = Property.includes(images_attachments: :blob, video_attachment: :blob, owner: { profile_picture_attachment: :blob })

        # Default map is public: approved only. Staff can include more via status param.
        if current_user&.admin?
          scope = scope.where(approval_status: Array(params[:status])) if params[:status].present?
          scope = scope.where(listing_status: Array(params[:listing_status])) if params[:listing_status].present?
        elsif current_user&.role_owner?
          scope = scope.where('approval_status = ? OR owner_id = ?', 'approved', current_user.id)
        else
          scope = scope.visible_to_public
        end

        # Only return properties with coordinates
        scope = scope.where.not(latitude: nil, longitude: nil)

        # Filter by bounding box if provided
        if bounding_box_provided?
          scope = scope.where(
            'latitude >= ? AND latitude <= ? AND longitude >= ? AND longitude <= ?',
            params[:south].to_f,
            params[:north].to_f,
            params[:west].to_f,
            params[:east].to_f
          )
        end

        # Radius filter (simple lat/lng range, consistent with existing code)
        if radius_search_provided?
          center_lat = params[:center_latitude].to_f
          center_lng = params[:center_longitude].to_f
          radius_km = params[:radius_km].to_f
          radius_km = 10.0 if radius_km <= 0

          lat_range = radius_km / 111.0
          lng_range = radius_km / (111.0 * Math.cos(center_lat * Math::PI / 180.0))

          scope = scope.where(
            'latitude >= ? AND latitude <= ? AND longitude >= ? AND longitude <= ?',
            center_lat - lat_range,
            center_lat + lat_range,
            center_lng - lng_range,
            center_lng + lng_range
          )
        end

        scope = scope.where(city: params[:city]) if params[:city].present?
        scope = scope.where(country: params[:country]) if params[:country].present?
        scope = scope.where(region: params[:region]) if params[:region].present?
        scope = scope.where(purpose: params[:purpose]) if params[:purpose].present?
        scope = scope.where(property_type: Array(params[:property_type])) if params[:property_type].present?

        if params[:min_price].present?
          scope = scope.where('price >= ?', params[:min_price].to_d)
        end
        if params[:max_price].present?
          scope = scope.where('price <= ?', params[:max_price].to_d)
        end

        if params[:min_bedrooms].present?
          scope = scope.where('bedrooms >= ?', params[:min_bedrooms].to_i)
        end
        if params[:min_bathrooms].present?
          scope = scope.where('bathrooms >= ?', params[:min_bathrooms].to_i)
        end

        if params[:min_area_sqm].present?
          scope = scope.where('area_sqm >= ?', params[:min_area_sqm].to_d)
        end

        if params[:features].present?
          keys = Array(params[:features]).map(&:to_s).reject(&:blank?)
          keys.each do |k|
            scope = scope.where("features ->> ? = 'true'", k)
          end
        end

        if params[:search].present?
          scope = scope.where('title ILIKE ?', "%#{params[:search]}%")
        end

        case params[:sort_by]
        when 'price_asc'
          scope = scope.order(Arel.sql('price ASC NULLS LAST'), created_at: :desc)
        when 'price_desc'
          scope = scope.order(Arel.sql('price DESC NULLS LAST'), created_at: :desc)
        else
          scope = scope.order(created_at: :desc)
        end

        limit = [params[:limit]&.to_i || 200, 500].min
        scope.limit(limit).to_a
      end

      def bounding_box_provided?
        params[:north].present? && params[:south].present? && 
        params[:east].present? && params[:west].present?
      end

      def radius_search_provided?
        params[:center_latitude].present? && params[:center_longitude].present?
      end

      def calculate_bounds(items)
        return nil if items.empty?

        lats = []
        lngs = []

        items.each do |item|
          next unless item.respond_to?(:latitude) && item.respond_to?(:longitude)
          next if item.latitude.blank? || item.longitude.blank?
          lats << item.latitude.to_f
          lngs << item.longitude.to_f
        end

        return nil if lats.empty? || lngs.empty?

        {
          north: lats.max,
          south: lats.min,
          east: lngs.max,
          west: lngs.min,
          center: {
            latitude: (lats.max + lats.min) / 2.0,
            longitude: (lngs.max + lngs.min) / 2.0
          }
        }
      end

      def map_property_response(property)
        return nil unless property.coordinates?

        {
          id: property.id,
          type: 'property',
          title: property.title,
          approval_status: property.approval_status,
          listing_status: property.listing_status,
          purpose: property.purpose,
          coordinates: {
            latitude: property.latitude.to_f,
            longitude: property.longitude.to_f
          },
          address: {
            city: property.city,
            country: property.country,
            full_address: property.full_address
          },
          price: property.price,
          currency: property.currency,
          images: property.images.map { |img| attachment_url(img) },
          video: attachment_url(property.video)
        }
      end
    end
  end
end

