module Api
  module V1
    class VibeChecksController < ApplicationController
      before_action :require_authentication!
      before_action :set_event, only: [:create, :index]
      before_action :set_vibe_check, only: [:show, :update, :destroy, :mark_helpful]
      
      # GET /api/v1/events/:event_id/vibe_checks
      def index
        vibe_checks = @event.vibe_checks.published.includes(:user).recent
        
        # Filter by rating
        if params[:min_rating].present?
          vibe_checks = vibe_checks.where('overall_rating >= ?', params[:min_rating].to_i)
        end
        
        limit = [params[:limit]&.to_i || 20, 100].min
        offset = params[:offset]&.to_i || 0
        
        api_success(
          data: {
            event: {
              id: @event.id,
              title: @event.title,
              vibe_check_rating: @event.vibe_check_rating,
              vibe_checks_count: @event.vibe_checks_count
            },
            vibe_checks: vibe_checks.limit(limit).offset(offset).map { |vc| vibe_check_response(vc) },
            pagination: {
              limit: limit,
              offset: offset
            }
          }
        )
      end
      
      # POST /api/v1/events/:event_id/vibe_checks
      def create
        unless @event.can_submit_vibe_check?(current_user)
          api_error(message: 'You cannot submit a VibeCheck for this event. Event must be past and you must have attended.', status: :forbidden)
          return
        end
        
        booking = current_user.bookings.find_by(event: @event)
        
        vibe_check = @event.vibe_checks.build(
          user: current_user,
          booking: booking,
          overall_rating: params[:overall_rating],
          atmosphere_rating: params[:atmosphere_rating],
          music_rating: params[:music_rating],
          crowd_rating: params[:crowd_rating],
          service_rating: params[:service_rating],
          value_rating: params[:value_rating],
          review: params[:review],
          highlights: params[:highlights],
          lowlights: params[:lowlights],
          would_return: params[:would_return],
          would_recommend: params[:would_recommend]
        )
        
        if vibe_check.save
          api_success(
            data: { vibe_check: vibe_check_response(vibe_check) },
            message: 'VibeCheck submitted successfully',
            status: :created
          )
        else
          api_validation_error(errors: vibe_check.errors.full_messages)
        end
      end
      
      # GET /api/v1/vibe_checks/:id
      def show
        api_success(data: { vibe_check: vibe_check_response(@vibe_check, detailed: true) })
      end
      
      # PATCH /api/v1/vibe_checks/:id
      def update
        unless @vibe_check.user_id == current_user.id
          api_error(message: 'You can only update your own VibeChecks', status: :forbidden)
          return
        end
        
        if @vibe_check.update(vibe_check_params)
          api_success(
            data: { vibe_check: vibe_check_response(@vibe_check) },
            message: 'VibeCheck updated successfully'
          )
        else
          api_validation_error(errors: @vibe_check.errors.full_messages)
        end
      end
      
      # DELETE /api/v1/vibe_checks/:id
      def destroy
        unless @vibe_check.user_id == current_user.id || current_user.role_admin?
          api_error(message: 'Unauthorized', status: :forbidden)
          return
        end
        
        @vibe_check.destroy
        api_success(message: 'VibeCheck deleted successfully')
      end
      
      # POST /api/v1/vibe_checks/:id/helpful
      def mark_helpful
        @vibe_check.increment_helpful!
        
        api_success(
          data: { helpful_count: @vibe_check.helpful_count },
          message: 'Marked as helpful'
        )
      end
      
      # GET /api/v1/vibe_checks/my_checks
      def my_checks
        vibe_checks = current_user.vibe_checks.includes(:event).recent
        
        api_success(
          data: {
            vibe_checks: vibe_checks.map { |vc| vibe_check_response(vc, include_event: true) }
          }
        )
      end
      
      private
      
      def set_event
        @event = Event.find_by(id: params[:event_id])
        unless @event
          api_error(message: 'Event not found', status: :not_found)
          return
        end
      end
      
      def set_vibe_check
        @vibe_check = VibeCheck.find_by(id: params[:id])
        unless @vibe_check
          api_error(message: 'VibeCheck not found', status: :not_found)
          return
        end
      end
      
      def vibe_check_params
        params.permit(
          :overall_rating,
          :atmosphere_rating,
          :music_rating,
          :crowd_rating,
          :service_rating,
          :value_rating,
          :review,
          :highlights,
          :lowlights,
          :would_return,
          :would_recommend
        )
      end
      
      def vibe_check_response(vibe_check, include_event: false, detailed: false)
        response = {
          id: vibe_check.id,
          overall_rating: vibe_check.overall_rating,
          ratings: {
            atmosphere: vibe_check.atmosphere_rating,
            music: vibe_check.music_rating,
            crowd: vibe_check.crowd_rating,
            service: vibe_check.service_rating,
            value: vibe_check.value_rating,
            average: vibe_check.average_category_rating
          },
          review: vibe_check.review,
          would_return: vibe_check.would_return,
          would_recommend: vibe_check.would_recommend,
          helpful_count: vibe_check.helpful_count,
          user: {
            id: vibe_check.user.id,
            name: vibe_check.user.name
          },
          created_at: vibe_check.created_at.iso8601
        }
        
        if include_event
          response[:event] = {
            id: vibe_check.event.id,
            title: vibe_check.event.title,
            starts_at: vibe_check.event.starts_at
          }
        end
        
        if detailed
          response.merge!(
            highlights: vibe_check.highlights,
            lowlights: vibe_check.lowlights,
            status: vibe_check.status
          )
        end
        
        response
      end
    end
  end
end

