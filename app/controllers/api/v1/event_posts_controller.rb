module Api
  module V1
    class EventPostsController < ApplicationController
      before_action :require_authentication!
      before_action :set_event
      before_action :set_event_post, only: [:show, :update, :destroy, :like, :unlike]
      before_action :check_ownership, only: [:update, :destroy]
      
      # GET /api/v1/events/:event_id/posts
      def index
        posts = @event.event_posts.active.recent
        
        # Filter by user
        posts = posts.by_user(User.find(params[:user_id])) if params[:user_id].present?
        
        # Filter out posts from blocked users
        posts = posts.visible_to_user(current_user) if current_user.present?
        
        limit = [params[:limit]&.to_i || 20, 100].min
        offset = params[:offset]&.to_i || 0
        total_count = posts.count
        
        posts = posts.includes(:user, photos_attachments: :blob)
                    .limit(limit)
                    .offset(offset)
        
        api_success(
          data: {
            event_id: @event.id,
            event_title: @event.title,
            posts: posts.map { |post| event_post_response(post) },
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
      
      # GET /api/v1/events/:event_id/posts/:id
      def show
        api_success(
          data: {
            post: event_post_response(@event_post)
          },
          status: :ok
        )
      end
      
      # POST /api/v1/events/:event_id/posts
      def create
        # Check if user has access to post (must be booked/interested or event is public)
        unless can_post_to_event?
          api_error(message: 'You must be booked or interested in this event to post', status: :forbidden)
          return
        end
        
        event_post = @event.event_posts.build(event_post_params)
        event_post.user = current_user
        
        if event_post.save
          # Attach photos if provided
          if params[:photos].present?
            Array(params[:photos]).each do |photo|
              event_post.photos.attach(photo) if photo.present?
            end
          end
          
          # Reload to get attached photos
          event_post.reload
          
          api_success(
            data: {
              post: event_post_response(event_post)
            },
            message: 'Post created successfully',
            status: :created
          )
        else
          api_validation_error(errors: event_post.errors.full_messages)
        end
      rescue => e
        Rails.logger.error "Create Event Post Error: #{e.message}"
        api_error(message: 'Failed to create post', status: :internal_server_error)
      end
      
      # PATCH /api/v1/events/:event_id/posts/:id
      def update
        update_params = event_post_params
        
        # Remove photos if requested
        if params[:remove_photo_ids].present?
          photo_ids = Array(params[:remove_photo_ids])
          @event_post.photos.where(id: photo_ids).purge
        end
        
        if @event_post.update(update_params)
          # Add new photos if provided
          if params[:photos].present?
            Array(params[:photos]).each do |photo|
              @event_post.photos.attach(photo) if photo.present?
            end
          end
          
          @event_post.reload
          
          api_success(
            data: {
              post: event_post_response(@event_post)
            },
            message: 'Post updated successfully',
            status: :ok
          )
        else
          api_validation_error(errors: @event_post.errors.full_messages)
        end
      rescue => e
        Rails.logger.error "Update Event Post Error: #{e.message}"
        api_error(message: 'Failed to update post', status: :internal_server_error)
      end
      
      # DELETE /api/v1/events/:event_id/posts/:id
      def destroy
        if @event_post.soft_delete
          api_success(
            message: 'Post deleted successfully',
            status: :ok
          )
        else
          api_error(message: 'Failed to delete post', status: :internal_server_error)
        end
      end
      
      # POST /api/v1/events/:event_id/posts/:id/like
      def like
        if @event_post.user_liked?(current_user)
          api_error(message: 'You have already liked this post', status: :bad_request)
          return
        end
        
        like = @event_post.likes.build(user: current_user)
        if like.save
          @event_post.reload
          api_success(
            data: {
              post: event_post_response(@event_post)
            },
            message: 'Post liked successfully',
            status: :ok
          )
        else
          api_validation_error(errors: like.errors.full_messages)
        end
      end
      
      # DELETE /api/v1/events/:event_id/posts/:id/like
      def unlike
        like = @event_post.likes.find_by(user: current_user)
        unless like
          api_error(message: 'You have not liked this post', status: :bad_request)
          return
        end
        
        if like.destroy
          @event_post.reload
          api_success(
            data: {
              post: event_post_response(@event_post)
            },
            message: 'Post unliked successfully',
            status: :ok
          )
        else
          api_error(message: 'Failed to unlike post', status: :internal_server_error)
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
      
      def set_event_post
        @event_post = @event.event_posts.find_by(id: params[:id])
        unless @event_post
          api_error(message: 'Post not found', status: :not_found)
          return
        end
      end
      
      def check_ownership
        unless @event_post.user_id == current_user.id || current_user.role_admin?
          api_error(message: 'You can only modify your own posts', status: :forbidden)
          return
        end
      end
      
      def can_post_to_event?
        # Users can post if:
        # 1. They are booked to the event
        # 2. They have RSVP'd/interested in the event
        # 3. They are the venue owner
        # 4. They are an admin
        return true if current_user.role_admin?
        return true if @event.creator_id == current_user.id
        return true if @event.user_booked?(current_user)
        return true if @event.user_interested?(current_user)
        
        false
      end
      
      def event_post_params
        params.require(:event_post).permit(:content, :status)
      end
      
      def event_post_response(post)
        {
          id: post.id,
          event_id: post.event_id,
          user: {
            id: post.user.id,
            name: post.user.name,
            username: post.user.username,
            role: post.user.role,
            avatar_url: post.user.respond_to?(:avatar_url) && post.user.avatar_url.present? ? post.user.avatar_url : default_avatar_url
          },
          content: post.content,
          photos: post.photo_urls,
          photos_count: post.photos_count,
          has_photos: post.has_photos?,
          likes_count: post.likes_count,
          user_liked: current_user ? post.user_liked?(current_user) : false,
          status: post.status,
          created_at: post.created_at.iso8601,
          updated_at: post.updated_at.iso8601
        }
      end
    end
  end
end

