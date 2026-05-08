module Api
  module V1
    class RatingsController < ApplicationController
      before_action :require_authentication!
      before_action :set_venue, only: [:index, :create, :show, :update, :destroy]
      before_action :set_rating, only: [:show, :update, :destroy]
      before_action :check_rating_ownership, only: [:update, :destroy]
      
      # GET /api/v1/venues/:venue_id/ratings
      def index
        ratings = @venue.ratings.approved.order(created_at: :desc)
        
        # Limit results
        limit = [params[:limit]&.to_i || 20, 100].min
        offset = params[:offset]&.to_i || 0
        total_count = ratings.count
        ratings = ratings.limit(limit).offset(offset)
        
        api_success(
          data: {
            ratings: ratings.map { |rating| rating_response(rating) },
            summary: {
              average_rating: @venue.average_rating,
              total_ratings: @venue.ratings_count
            },
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
      
      # GET /api/v1/venues/:venue_id/ratings/:id
      def show
        api_success(data: { rating: rating_response(@rating) }, status: :ok)
      end
      
      # GET /api/v1/venues/:venue_id/ratings/my_rating
      def my_rating
        rating = @venue.user_rating(current_user)
        if rating
          api_success(data: { rating: rating_response(rating) }, status: :ok)
        else
          api_success(data: { rating: nil }, message: 'You have not rated this venue yet', status: :ok)
        end
      end
      
      # POST /api/v1/venues/:venue_id/ratings
      def create
        # Check if user already rated this venue
        existing_rating = @venue.user_rating(current_user)
        if existing_rating
          api_error(message: 'You have already rated this venue. Use update to modify your rating.', status: :bad_request)
          return
        end
        
        rating = @venue.ratings.build(rating_params.merge(user: current_user))
        
        if rating.save
          api_success(
            data: { rating: rating_response(rating) },
            message: 'Rating created successfully',
            status: :created
          )
        else
          api_validation_error(errors: rating.errors.full_messages)
        end
      end
      
      # PATCH/PUT /api/v1/venues/:venue_id/ratings/:id
      def update
        if @rating.update(rating_params)
          api_success(
            data: { rating: rating_response(@rating) },
            message: 'Rating updated successfully',
            status: :ok
          )
        else
          api_validation_error(errors: @rating.errors.full_messages)
        end
      end
      
      # DELETE /api/v1/venues/:venue_id/ratings/:id
      def destroy
        if @rating.destroy
          api_success(message: 'Rating deleted successfully', status: :ok)
        else
          api_validation_error(errors: @rating.errors.full_messages)
        end
      end
      
      private
      
      def set_venue
        @venue = Venue.find_by(id: params[:venue_id])
        unless @venue
          api_error(message: 'Venue not found', status: :not_found)
          return
        end
      end
      
      def set_rating
        @rating = @venue.ratings.find_by(id: params[:id])
        unless @rating
          api_error(message: 'Rating not found', status: :not_found)
          return
        end
      end
      
      def check_rating_ownership
        unless @rating.user_id == current_user.id || current_user.role_admin?
          api_error(message: 'You can only modify your own ratings', status: :forbidden)
          return
        end
      end
      
      def rating_params
        params.require(:rating).permit(:rating, :comment)
      end
      
      def rating_response(rating)
        {
          id: rating.id,
          rating: rating.rating,
          comment: rating.comment,
          moderation_status: rating.moderation_status,
          published_at: rating.published_at,
          user: {
            id: rating.user.id,
            name: rating.user.name
          },
          created_at: rating.created_at,
          updated_at: rating.updated_at
        }
      end
    end
  end
end

