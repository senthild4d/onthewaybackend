module Api
  module V1
    class LikesController < ApplicationController
      before_action :require_authentication!
      before_action :set_likeable, only: [:index, :create, :destroy, :check_like, :toggle]
      
      # GET /api/v1/events/:event_id/likes
      # GET /api/v1/venues/:venue_id/likes
      def index
        likes = @likeable.likes.includes(:user)
        
        # Limit results
        limit = [params[:limit]&.to_i || 20, 100].min
        offset = params[:offset]&.to_i || 0
        total_count = likes.count
        likes = likes.order(created_at: :desc).limit(limit).offset(offset)
        
        api_success(
          data: {
            likeable: {
              id: @likeable.id,
              type: @likeable.class.name,
              likes_count: @likeable.likes_count
            },
            likes: likes.map { |like| like_response(like) },
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
      
      # GET /api/v1/events/:event_id/likes/check
      # GET /api/v1/venues/:venue_id/likes/check
      def check_like
        liked = @likeable.user_liked?(current_user)
        api_success(
          data: { 
            liked: liked,
            likes_count: @likeable.likes_count
          },
          status: :ok
        )
      end
      
      # POST /api/v1/events/:event_id/likes
      # POST /api/v1/venues/:venue_id/likes
      def create
        # Check if already liked
        existing_like = @likeable.likes.find_by(user: current_user)
        if existing_like
          api_error(message: 'You have already liked this item', status: :bad_request)
          return
        end
        
        like = @likeable.likes.build(user: current_user)
        
        if like.save
          api_success(
            data: { like: like_response(like) },
            message: 'Liked successfully',
            status: :created
          )
        else
          api_validation_error(errors: like.errors.full_messages)
        end
      end
      
      # DELETE /api/v1/events/:event_id/likes
      # DELETE /api/v1/venues/:venue_id/likes
      def destroy
        like = @likeable.likes.find_by(user: current_user)
        
        unless like
          api_error(message: 'You have not liked this item', status: :not_found)
          return
        end
        
        if like.destroy
          api_success(message: 'Unliked successfully', status: :ok)
        else
          api_validation_error(errors: like.errors.full_messages)
        end
      end
      
      # PUT /api/v1/events/:event_id/likes/toggle
      # PUT /api/v1/venues/:venue_id/likes/toggle
      # PATCH /api/v1/events/:event_id/likes/toggle
      # PATCH /api/v1/venues/:venue_id/likes/toggle
      def toggle
        existing_like = @likeable.likes.find_by(user: current_user)
        
        if existing_like
          # Unlike
          if existing_like.destroy
            @likeable.reload
            api_success(
              data: {
                liked: false,
                likes_count: @likeable.likes_count
              },
              message: 'Unliked successfully',
              status: :ok
            )
          else
            api_validation_error(errors: existing_like.errors.full_messages)
          end
        else
          # Like
          like = @likeable.likes.build(user: current_user)
          if like.save
            @likeable.reload
            api_success(
              data: {
                liked: true,
                like: like_response(like),
                likes_count: @likeable.likes_count
              },
              message: 'Liked successfully',
              status: :ok
            )
          else
            api_validation_error(errors: like.errors.full_messages)
          end
        end
      end
      
      private
      
      def set_likeable
        if params[:event_id].present?
          @likeable = Event.find_by(id: params[:event_id])
          unless @likeable
            api_error(message: 'Event not found', status: :not_found)
            return
          end
        elsif params[:venue_id].present?
          @likeable = Venue.find_by(id: params[:venue_id])
          unless @likeable
            api_error(message: 'Venue not found', status: :not_found)
            return
          end
        else
          api_error(message: 'Event or Venue ID is required', status: :bad_request)
          return
        end
      end
      
      def like_response(like)
        {
          id: like.id,
          user: {
            id: like.user.id,
            name: like.user.name
          },
          created_at: like.created_at
        }
      end
    end
  end
end

