# frozen_string_literal: true

module Api
  module V1
    class MapsController < ApplicationController
      include PropertySerializable
      include MapsPropertyScoping

      before_action :require_authentication!, except: [:index, :filter_options]

      # GET /api/v1/maps
      # Vibes-style query (properties replace venues/events):
      #   show_properties=true
      #   center_latitude, center_longitude, radius_km
      #   north, south, east, west
      #   city, country, region, search, purpose, property_type (or legacy category)
      #   min_price, max_price, min_bedrooms, features[], sort_by, limit
      # Legacy aliases: show_venues, show_events, event_status, category
      def index
        properties_array = []
        if show_map_properties?
          properties_array = fetch_map_properties
          preload_favorite_property_ids!(properties_array)
        end

        map_data = {
          properties: properties_array.map { |p| map_property_response(p) }.compact,
          bounds: calculate_bounds(properties_array),
          metadata: map_metadata(properties_array)
        }

        api_success(data: map_data, status: :ok)
      end

      # GET /api/v1/maps/filter_options
      def filter_options
        base = PropertyOptions.filter_options(admin: current_user&.admin?)

        options = base.merge(
          show_properties: { default: true, description: 'Include property markers (legacy: show_venues / show_events)' },
          radius_options: [
            { value: 1, label: '1 km' },
            { value: 5, label: '5 km' },
            { value: 10, label: '10 km' },
            { value: 25, label: '25 km' },
            { value: 50, label: '50 km' },
            { value: 100, label: '100 km' }
          ],
          sort_options: [
            { value: 'distance', label: 'Distance (requires center_latitude & center_longitude)' },
            { value: 'newest', label: 'Newest' },
            { value: 'oldest', label: 'Oldest' },
            { value: 'price_asc', label: 'Price (low to high)' },
            { value: 'price_desc', label: 'Price (high to low)' }
          ],
          query_params: map_query_param_docs
        )

        api_success(data: options, status: :ok)
      end

      private

      def map_metadata(properties_array)
        {
          properties_count: properties_array.count,
          total_markers: properties_array.count,
          properties_with_360_count: properties_array.count { |property| property.video_projection_equirectangular? && property.video.attached? },
          show_properties: show_map_properties?,
          center: map_radius_search_provided? ? {
            latitude: params[:center_latitude].to_f,
            longitude: params[:center_longitude].to_f,
            radius_km: (params[:radius_km].presence || 10).to_f
          } : nil
        }
      end

      def map_query_param_docs
        {
          show_properties: 'true|false (default true). Legacy: show_venues, show_events',
          center_latitude: 'Center for radius / distance sort',
          center_longitude: 'Center for radius / distance sort',
          radius_km: 'Radius in km (default 10 when center set)',
          north: 'Bounding box',
          south: 'Bounding box',
          east: 'Bounding box',
          west: 'Bounding box',
          city: 'City filter',
          country: 'Country filter',
          region: 'Region filter',
          search: 'Search title, description, address, city, …',
          purpose: 'sale | rent',
          property_type: 'Property type (array). Legacy alias: category',
          currency: 'USD, USDT, AED, …',
          min_price: 'Minimum price',
          max_price: 'Maximum price',
          min_bedrooms: 'Minimum bedrooms',
          max_bedrooms: 'Maximum bedrooms',
          min_bathrooms: 'Minimum bathrooms',
          max_bathrooms: 'Maximum bathrooms',
          min_area_sqm: 'Minimum area sqm',
          max_area_sqm: 'Maximum area sqm',
          has_360_view: 'true to return only properties with equirectangular video attached',
          features: 'features[] repeatable',
          approval_status: 'Admin: draft, pending_review, approved, rejected',
          listing_status: 'Admin: active, sold, archived',
          status: 'Admin alias for approval_status',
          event_status: 'Legacy alias (published→approved)',
          sort_by: 'distance, newest, oldest, price_asc, price_desc',
          limit: 'Max markers (default 200, max 500)',
          view_360: 'Response field: available when video_projection=equirectangular and video is present'
        }
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

        property_response(property, detailed: true).merge(type: 'property')
      end
    end
  end
end
