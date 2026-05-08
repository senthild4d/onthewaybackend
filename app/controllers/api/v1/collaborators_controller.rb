module Api
  module V1
    class CollaboratorsController < ApplicationController
      before_action :require_authentication!

      # GET /api/v1/collaborators/search?q=...
      # Autocomplete for venues and brands to collaborate with on events.
      def search
        q = params[:q].to_s.strip
        if q.length < 2
          api_error(message: 'Search query must be at least 2 characters', status: :bad_request)
          return
        end

        limit = [params[:limit]&.to_i || 20, 50].min

        venues = Venue.active.where(owner_id: current_user.id)
                      .where('venues.name ILIKE :q OR venues.city ILIKE :q', q: "%#{q}%")
                      .limit(limit)

        brands = User.active.role_brand
                     .where('users.username ILIKE :q OR users.name ILIKE :q', q: "%#{q}%")
                     .limit(limit)

        results = []

        venues.each do |venue|
          results << {
            type: 'venue',
            id: venue.id,
            name: venue.name
          }
        end

        brands.each do |brand|
          results << {
            type: 'brand',
            id: brand.id,
            name: brand.name.presence || brand.username
          }
        end

        # Enforce overall limit across both sets
        results = results.first(limit)

        api_success(
          data: { results: results },
          status: :ok
        )
      end
    end
  end
end

