module Api
  module V1
    class EventReviewsController < ApplicationController
      before_action :require_authentication!, except: [:index, :show]
      before_action :set_event, only: [:index, :create]
      before_action :set_review, only: [:show, :update, :destroy]
      before_action :check_review_ownership, only: [:update, :destroy]
      
      # GET /api/v1/events/:event_id/reviews
      def index
        reviews = @event.ratings.approved.includes(:user).order(created_at: :desc)
        
        # Filter by min rating
        if params[:min_rating].present?
          reviews = reviews.where('rating >= ?', params[:min_rating].to_i)
        end
        
        # Limit results
        limit = [params[:limit]&.to_i || 20, 100].min
        offset = params[:offset]&.to_i || 0
        total_count = reviews.count
        reviews = reviews.limit(limit).offset(offset)
        
        api_success(
          data: {
            event: {
              id: @event.id,
              title: @event.title,
              average_rating: @event.average_rating,
              reviews_count: @event.reviews_count
            },
            reviews: reviews.map { |review| review_response(review) },
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
      
      # GET /api/v1/events/:event_id/reviews/:id
      def show
        api_success(data: { review: review_response(@review) }, status: :ok)
      end
      
      # GET /api/v1/events/:event_id/reviews/my_review
      def my_review
        unless current_user
          api_error(message: 'Authentication required', status: :unauthorized)
          return
        end
        
        review = @event.ratings.find_by(user: current_user)
        if review
          api_success(data: { review: review_response(review) }, status: :ok)
        else
          api_success(data: { review: nil }, message: 'You have not reviewed this event yet', status: :ok)
        end
      end
      
      # POST /api/v1/events/:event_id/reviews
      def create
        # Check if user already reviewed this event
        existing_review = @event.ratings.find_by(user: current_user)
        if existing_review
          api_error(message: 'You have already reviewed this event. Use update to modify your review.', status: :bad_request)
          return
        end
        
        review = @event.ratings.build(review_params.merge(user: current_user))
        
        if review.save
          api_success(
            data: { review: review_response(review) },
            message: 'Review created successfully',
            status: :created
          )
        else
          api_validation_error(errors: review.errors.full_messages)
        end
      end
      
      # PATCH/PUT /api/v1/events/:event_id/reviews/:id
      def update
        if @review.update(review_params)
          api_success(
            data: { review: review_response(@review) },
            message: 'Review updated successfully',
            status: :ok
          )
        else
          api_validation_error(errors: @review.errors.full_messages)
        end
      end
      
      # DELETE /api/v1/events/:event_id/reviews/:id
      def destroy
        if @review.destroy
          api_success(message: 'Review deleted successfully', status: :ok)
        else
          api_validation_error(errors: @review.errors.full_messages)
        end
      end
      
      private
      
      def set_event
        @event = Event.find_by(id: params[:event_id])
        unless @event
          api_error(message: 'Event not found', status: :not_found)
          return
        end
      end
      
      def set_review
        event_id = params[:event_id] || params.dig(:review, :event_id)
        @event = Event.find_by(id: event_id)
        unless @event
          api_error(message: 'Event not found', status: :not_found)
          return
        end
        
        @review = @event.ratings.find_by(id: params[:id])
        unless @review
          api_error(message: 'Review not found', status: :not_found)
          return
        end
      end
      
      def check_review_ownership
        unless @review.user_id == current_user.id || current_user.role_admin?
          api_error(message: 'You can only modify your own reviews', status: :forbidden)
          return
        end
      end
      
      def review_params
        params.require(:review).permit(:rating, :comment)
      end
      
      def review_response(review)
        event = review.rateable
        user = review.user
        
        # Generate full avatar URL (use default when no profile picture)
        avatar_url = if user.profile_picture.attached?
          url_for(user.profile_picture)
        elsif user.profile_picture_url.present?
          user.profile_picture_url
        else
          default_avatar_url
        end
        
        {
          id: review.id,
          rating: review.rating,
          rating_out_of_10: (review.rating * 2.0).round(1), # Convert 1-5 to 1-10 scale
          comment: review.comment,
          moderation_status: review.moderation_status,
          published_at: review.published_at&.iso8601,
          user: {
            id: user.id,
            name: user.name,
            username: user.username,
            avatar_url: avatar_url
          },
          event: {
            id: event.id,
            title: event.title,
            name: event.title # Alias for consistency
          },
          created_at: review.created_at.iso8601,
          updated_at: review.updated_at.iso8601
        }
      end
    end
  end
end
