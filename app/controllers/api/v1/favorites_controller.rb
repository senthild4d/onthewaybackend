module Api
  module V1
    class FavoritesController < ApplicationController
      before_action :require_authentication!
      before_action :set_property, only: [:create, :destroy]

      # GET /api/v1/favorites
      def index
        favorites = current_user.favorites.includes(property: [images_attachments: :blob, video_attachment: :blob]).order(created_at: :desc)
        api_success(
          data: {
            favorites: favorites.map { |f| favorite_response(f) }
          },
          status: :ok
        )
      end

      # POST /api/v1/properties/:property_id/favorite
      def create
        fav = current_user.favorites.find_or_initialize_by(property_id: @property.id)
        if fav.save
          api_success(data: { favorite: favorite_response(fav) }, message: 'Added to favorites', status: :ok)
        else
          api_validation_error(errors: fav.errors.full_messages)
        end
      end

      # DELETE /api/v1/properties/:property_id/favorite
      def destroy
        fav = current_user.favorites.find_by(property_id: @property.id)
        unless fav
          api_success(message: 'Already removed', status: :ok, data: { property_id: @property.id })
          return
        end
        fav.destroy
        api_success(message: 'Removed from favorites', status: :ok, data: { property_id: @property.id })
      end

      private

      def set_property
        @property = Property.find_by(id: params[:property_id])
        unless @property
          api_error(message: 'Property not found', status: :not_found)
        end
      end

      def favorite_response(fav)
        {
          id: fav.id,
          property_id: fav.property_id,
          created_at: fav.created_at&.iso8601
        }
      end
    end
  end
end

