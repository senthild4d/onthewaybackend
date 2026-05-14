module Api
  module V1
    class SearchController < ApplicationController
      include PropertySerializable

      # GET /api/v1/search?q=keyword
      # Optional: purpose, property_type, city, country, min_price, max_price,
      #           min_bedrooms, max_bedrooms, sort_by, page, per_page
      def index
        term = (params[:q] || params[:search] || params[:query]).to_s.strip
        search_type = params[:type].presence || 'properties'

        case search_type
        when 'owners'
          search_owners(term)
        else
          search_properties(term)
        end
      end

      private

      def search_properties(term)
        scope = Property.includes(images_attachments: :blob, video_attachment: :blob, owner: { profile_picture_attachment: :blob })
        scope = apply_visibility(scope)
        scope = apply_property_filters(scope)

        if term.present?
          q = "%#{term}%"
          scope = scope.where(
            'title ILIKE ? OR description ILIKE ? OR city ILIKE ? OR region ILIKE ? OR country ILIKE ? OR address1 ILIKE ? OR address2 ILIKE ? OR postal_code ILIKE ? OR property_type ILIKE ?',
            q, q, q, q, q, q, q, q, q
          )
        end

        scope = apply_sort(scope)

        page, per_page, offset = pagination_params(default_per_page: 20, max_per_page: 100)
        total_count = scope.count
        total_pages = (total_count.to_f / per_page).ceil
        results = scope.limit(per_page).offset(offset)
        preload_favorite_property_ids!(results)

        suggestions = term.present? ? build_suggestions(term) : {}

        api_success(
          data: {
            query: term.presence,
            type: 'properties',
            properties: results.map { |p| property_response(p, detailed: true) },
            suggestions: suggestions,
            pagination: pagination_meta(page, per_page, total_count, total_pages)
          },
          status: :ok
        )
      end

      def search_owners(term)
        if term.blank?
          api_error(message: 'Search query (q) is required for owner search', status: :bad_request)
          return
        end

        q = "%#{term}%"
        scope = User.active
                    .where(role: 'owner')
                    .where(
                      'name ILIKE ? OR username ILIKE ? OR description ILIKE ? OR address ILIKE ? OR email ILIKE ?',
                      q, q, q, q, q
                    )

        page, per_page, offset = pagination_params(default_per_page: 20, max_per_page: 100)
        total_count = scope.count
        total_pages = (total_count.to_f / per_page).ceil
        results = scope.order(created_at: :desc).limit(per_page).offset(offset)

        api_success(
          data: {
            query: term,
            type: 'owners',
            owners: results.map { |u| owner_search_response(u) },
            pagination: pagination_meta(page, per_page, total_count, total_pages)
          },
          status: :ok
        )
      end

      def apply_visibility(scope)
        if current_user&.role_owner?
          scope.where('approval_status = ? OR owner_id = ?', 'approved', current_user.id)
        elsif current_user&.admin?
          scope
        else
          scope.visible_to_public
        end
      end

      def apply_property_filters(scope)
        scope = scope.where(purpose: params[:purpose]) if params[:purpose].present?
        scope = scope.where(property_type: Array(params[:property_type])) if params[:property_type].present?
        scope = scope.where(country: params[:country]) if params[:country].present?
        scope = scope.where(region: params[:region]) if params[:region].present?
        scope = scope.where(city: params[:city]) if params[:city].present?

        scope = scope.where('price >= ?', params[:min_price].to_d) if params[:min_price].present?
        scope = scope.where('price <= ?', params[:max_price].to_d) if params[:max_price].present?
        scope = scope.where('bedrooms >= ?', params[:min_bedrooms].to_i) if params[:min_bedrooms].present?
        scope = scope.where('bedrooms <= ?', params[:max_bedrooms].to_i) if params[:max_bedrooms].present?
        scope = scope.where('bathrooms >= ?', params[:min_bathrooms].to_i) if params[:min_bathrooms].present?
        scope = scope.where('bathrooms <= ?', params[:max_bathrooms].to_i) if params[:max_bathrooms].present?
        scope = scope.where('area_sqm >= ?', params[:min_area_sqm].to_d) if params[:min_area_sqm].present?
        scope = scope.where('area_sqm <= ?', params[:max_area_sqm].to_d) if params[:max_area_sqm].present?

        if params[:features].present?
          Array(params[:features]).map(&:to_s).reject(&:blank?).each do |k|
            scope = scope.where("features ->> ? = 'true'", k)
          end
        end

        if params[:north].present? && params[:south].present? && params[:east].present? && params[:west].present?
          scope = scope.where(
            'latitude >= ? AND latitude <= ? AND longitude >= ? AND longitude <= ?',
            params[:south].to_f, params[:north].to_f, params[:west].to_f, params[:east].to_f
          )
        end

        scope
      end

      def apply_sort(scope)
        case params[:sort_by].to_s
        when 'price_asc' then scope.order(Arel.sql('price ASC NULLS LAST'), created_at: :desc)
        when 'price_desc' then scope.order(Arel.sql('price DESC NULLS LAST'), created_at: :desc)
        when 'oldest' then scope.order(created_at: :asc)
        else scope.order(created_at: :desc)
        end
      end

      def build_suggestions(term)
        q = "%#{term}%"
        public_scope = Property.visible_to_public

        {
          cities: public_scope.where('city ILIKE ?', q).distinct.limit(10).pluck(:city).compact,
          regions: public_scope.where('region ILIKE ?', q).distinct.limit(10).pluck(:region).compact,
          countries: public_scope.where('country ILIKE ?', q).distinct.limit(10).pluck(:country).compact,
          property_types: public_scope.where('property_type ILIKE ?', q).distinct.limit(10).pluck(:property_type).compact
        }
      end

      def owner_search_response(user)
        avatar = attachment_url(user.profile_picture) || user.profile_picture_url.presence || default_avatar_url

        {
          id: user.id,
          name: user.name,
          username: user.username,
          description: user.description,
          address: user.address,
          avatar_url: avatar,
          properties_count: Property.where(owner_id: user.id, approval_status: 'approved', listing_status: 'active').count
        }
      end

      def pagination_meta(page, per_page, total_count, total_pages)
        {
          page: page,
          per_page: per_page,
          total_count: total_count,
          total_pages: total_pages,
          has_next_page: page < total_pages,
          has_prev_page: page > 1
        }
      end
    end
  end
end
