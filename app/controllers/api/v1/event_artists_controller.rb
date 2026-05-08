module Api
  module V1
    class EventArtistsController < ApplicationController
      before_action :require_authentication!
      before_action :set_event
      before_action :set_event_artist, only: [:show, :update, :destroy, :cancel, :confirm]
      before_action :check_event_permission, only: [:create, :update, :destroy, :cancel, :confirm, :bulk_add, :bulk_remove]
      
      # GET /api/v1/events/:event_id/artists
      def index
        event_artists = @event.event_artists.ordered
        
        # Filter by status
        event_artists = event_artists.where(status: params[:status]) if params[:status].present?
        
        api_success(
          data: {
            event_id: @event.id,
            event_title: @event.title,
            artists: event_artists.map { |ea| event_artist_response(ea) }
          },
          status: :ok
        )
      end
      
      # GET /api/v1/events/:event_id/artists/:id
      def show
        api_success(
          data: {
            event_artist: event_artist_response(@event_artist)
          },
          status: :ok
        )
      end
      
      # POST /api/v1/events/:event_id/artists
      # Accepts either artist_id (User with artist role) OR artist_name (free-form text)
      def create
        artist_id = params[:artist_id] || params.dig(:event_artist, :artist_id)
        artist_name = params[:artist_name] || params.dig(:event_artist, :artist_name)

        if artist_id.present?
          # Linked artist: must be a User with artist role
          artist = User.find_by(id: artist_id)
          unless artist&.role_artist?
            api_error(message: 'User must have artist role', status: :bad_request)
            return
          end
          if @event.event_artists.exists?(artist_id: artist.id)
            api_error(message: 'Artist is already added to this event', status: :bad_request)
            return
          end
        elsif artist_name.present?
          # Free-form artist name
          artist = nil
        else
          api_error(message: 'Either artist_id or artist_name is required', status: :bad_request)
          return
        end

        event_artist = @event.event_artists.build(event_artist_params)
        event_artist.artist = artist if artist
        event_artist.artist_name = artist_name if artist_name.present?
        event_artist.timezone ||= @event.timezone

        # Set display_order if not provided (add to end)
        if event_artist.display_order.nil?
          max_order = @event.event_artists.maximum(:display_order) || -1
          event_artist.display_order = max_order + 1
        end

        if event_artist.save
          api_success(
            data: {
              event_artist: event_artist_response(event_artist)
            },
            message: 'Artist added to event successfully',
            status: :created
          )
        else
          api_validation_error(errors: event_artist.errors.full_messages)
        end
      rescue => e
        Rails.logger.error "Add Event Artist Error: #{e.message}"
        api_error(message: 'Failed to add artist to event', status: :internal_server_error)
      end
      
      # PATCH /api/v1/events/:event_id/artists/:id
      def update
        update_params = event_artist_params
        
        if @event_artist.update(update_params)
          api_success(
            data: {
              event_artist: event_artist_response(@event_artist)
            },
            message: 'Artist schedule updated successfully',
            status: :ok
          )
        else
          api_validation_error(errors: @event_artist.errors.full_messages)
        end
      rescue => e
        Rails.logger.error "Update Event Artist Error: #{e.message}"
        api_error(message: 'Failed to update artist schedule', status: :internal_server_error)
      end
      
      # DELETE /api/v1/events/:event_id/artists/:id
      def destroy
        if @event_artist.destroy
          api_success(
            message: 'Artist removed from event successfully',
            status: :ok
          )
        else
          api_error(message: 'Failed to remove artist from event', status: :internal_server_error)
        end
      end
      
      # POST /api/v1/events/:event_id/artists/:id/cancel
      def cancel
        @event_artist.cancel!
        api_success(
          data: {
            event_artist: event_artist_response(@event_artist)
          },
          message: 'Artist schedule cancelled successfully',
          status: :ok
        )
      end
      
      # POST /api/v1/events/:event_id/artists/:id/confirm
      def confirm
        @event_artist.confirm!
        api_success(
          data: {
            event_artist: event_artist_response(@event_artist)
          },
          message: 'Artist schedule confirmed successfully',
          status: :ok
        )
      end
      
      # POST /api/v1/events/:event_id/artists/bulk
      # Bulk add multiple artists to event (transactional - all or nothing)
      # Body: { artists: [{ artist_id: "", scheduled_start_at: "", scheduled_end_at: "" }, ...] }
      # OR simple: { artist_ids: ["uuid1", "uuid2", ...] } - uses event times as defaults
      def bulk_add
        # Accept either array of artist objects or simple array of IDs
        artist_ids = params[:artist_ids] || []
        
        # Permit the artists array properly if it exists
        if params[:artists].present?
          permitted_params = params.permit(artists: [:artist_id, :artist_name, :scheduled_start_at, :scheduled_end_at, :timezone, :display_order, :description, :status])
          artists_data = permitted_params[:artists] || []
        else
          artists_data = []
        end
        
        if artists_data.empty? && artist_ids.empty?
          api_error(message: 'artists or artist_ids array is required', status: :bad_request)
          return
        end
        
        # Process simple artist_ids array (uses event times as defaults)
        if artist_ids.present?
          artists_data = artist_ids.map do |id|
            { 
              artist_id: id, 
              scheduled_start_at: @event.starts_at, 
              scheduled_end_at: @event.ends_at 
            }
          end
        end
        
        # Validate all artists first before saving any (transactional approach)
        validated_artists = []
        errors_list = []
        
        artists_data.each_with_index do |artist_data, index|
          # Convert to hash with indifferent access
          if artist_data.is_a?(ActionController::Parameters)
            artist_data = artist_data.to_h.with_indifferent_access
          elsif artist_data.is_a?(Hash)
            artist_data = artist_data.with_indifferent_access
          else
            artist_data = artist_data.to_h.with_indifferent_access
          end
          
          artist_id = artist_data[:artist_id]
          artist_name = artist_data[:artist_name]

          unless artist_id.present? || artist_name.present?
            errors_list << { index: index, error: 'Either artist_id or artist_name is required' }
            next
          end

          artist = nil
          if artist_id.present?
            # Linked artist: must be a User with artist role
            artist = User.find_by(id: artist_id)
            unless artist
              errors_list << { index: index, artist_id: artist_id, error: 'Artist not found' }
              next
            end
            unless artist.role_artist?
              errors_list << { index: index, artist_id: artist_id, error: 'User must have artist role' }
              next
            end
            if @event.event_artists.exists?(artist_id: artist.id)
              errors_list << { index: index, artist_id: artist_id, error: 'Artist already added to event' }
              next
            end
          end
          
          # Parse datetime strings if provided
          begin
            scheduled_start_at = if artist_data[:scheduled_start_at].present?
              Time.parse(artist_data[:scheduled_start_at].to_s)
            else
              @event.starts_at
            end
          rescue ArgumentError => e
            errors_list << { 
              index: index, 
              artist_id: artist_id, 
              error: "Invalid scheduled_start_at format: #{artist_data[:scheduled_start_at]}"
            }
            next
          end
          
          begin
            scheduled_end_at = if artist_data[:scheduled_end_at].present?
              Time.parse(artist_data[:scheduled_end_at].to_s)
            else
              @event.ends_at
            end
          rescue ArgumentError => e
            errors_list << { 
              index: index, 
              artist_id: artist_id, 
              error: "Invalid scheduled_end_at format: #{artist_data[:scheduled_end_at]}"
            }
            next
          end
          
          # Validate dates before attempting to save
          if scheduled_start_at < @event.starts_at
            errors_list << { 
              index: index, 
              artist_id: artist_id, 
              error: "Scheduled start time (#{scheduled_start_at.iso8601}) cannot be before event start time (#{@event.starts_at.iso8601})"
            }
            next
          end
          
          if scheduled_end_at > @event.ends_at
            errors_list << { 
              index: index, 
              artist_id: artist_id, 
              error: "Scheduled end time (#{scheduled_end_at.iso8601}) cannot be after event end time (#{@event.ends_at.iso8601})"
            }
            next
          end
          
          if scheduled_end_at <= scheduled_start_at
            errors_list << { 
              index: index, 
              artist_id: artist_id, 
              error: "Scheduled end time must be after scheduled start time"
            }
            next
          end
          
          # All validations passed - add to validated list
          validated_artists << {
            index: index,
            artist: artist,
            artist_id: artist_id,
            artist_name: artist_name,
            scheduled_start_at: scheduled_start_at,
            scheduled_end_at: scheduled_end_at,
            timezone: artist_data[:timezone] || @event.timezone,
            display_order: artist_data[:display_order],
            description: artist_data[:description],
            status: artist_data[:status] || 'pending'
          }
        end
        
        # If any validation errors, return them all without saving anything
        if errors_list.any?
          api_error(
            message: 'Validation failed for one or more artists. No artists were added.',
            status: :bad_request,
            data: { errors: errors_list }
          )
          return
        end
        
        # All validations passed - save all in a single transaction
        added_artists = []
        transaction_error = nil
        
        begin
          ActiveRecord::Base.transaction do
            max_order = @event.event_artists.maximum(:display_order) || -1
            
            validated_artists.each_with_index do |artist_data, idx|
              event_artist = @event.event_artists.build(
                artist: artist_data[:artist],
                artist_name: artist_data[:artist_name],
                scheduled_start_at: artist_data[:scheduled_start_at],
                scheduled_end_at: artist_data[:scheduled_end_at],
                timezone: artist_data[:timezone],
                display_order: artist_data[:display_order] || (max_order + 1 + idx),
                description: artist_data[:description],
                status: artist_data[:status]
              )
              
              unless event_artist.save
                # If any save fails, set error and raise to rollback the entire transaction
                transaction_error = {
                  index: artist_data[:index],
                  artist_id: artist_data[:artist_id],
                  artist_name: artist_data[:artist_name],
                  error: event_artist.errors.full_messages.join(', ')
                }
                raise ActiveRecord::RecordInvalid.new(event_artist)
              end
              
              added_artists << event_artist_response(event_artist)
            end
          end
        rescue ActiveRecord::RecordInvalid => e
          # Transaction was rolled back, return error
          api_error(
            message: 'Failed to add one or more artists. No artists were added.',
            status: :unprocessable_entity,
            data: { error: transaction_error || { error: e.message } }
          )
          return
        end
        
        # Transaction completed successfully - all artists were added
        api_success(
          data: {
            event_id: @event.id,
            event_title: @event.title,
            artists: added_artists,
            count: added_artists.length
          },
          message: "Successfully added #{added_artists.length} artist(s) to event",
          status: :created
        )
      rescue => e
        Rails.logger.error "Bulk Add Event Artists Error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        api_error(
          message: 'Failed to add artists to event',
          status: :internal_server_error
        )
      end
      
      # DELETE /api/v1/events/:event_id/artists/bulk
      # Bulk remove artists from event
      # Body: { artist_ids: ["uuid1", "uuid2"] } or { event_artist_ids: ["uuid1", "uuid2"] }
      def bulk_remove
        artist_ids = params[:artist_ids] || []
        event_artist_ids = params[:event_artist_ids] || []
        
        if artist_ids.empty? && event_artist_ids.empty?
          api_error(message: 'artist_ids or event_artist_ids array is required', status: :bad_request)
          return
        end
        
        removed = []
        errors_list = []
        
        # Remove by event_artist_ids (primary key)
        if event_artist_ids.present?
          event_artist_ids.each do |ea_id|
            event_artist = @event.event_artists.find_by(id: ea_id)
            if event_artist
              if event_artist.destroy
                removed << { id: ea_id, artist_id: event_artist.artist_id }
              else
                errors_list << { id: ea_id, error: 'Failed to remove' }
              end
            else
              errors_list << { id: ea_id, error: 'Event artist not found' }
            end
          end
        end
        
        # Remove by artist_ids (user IDs)
        if artist_ids.present?
          artist_ids.each do |artist_id|
            event_artist = @event.event_artists.find_by(artist_id: artist_id)
            if event_artist
              if event_artist.destroy
                removed << { artist_id: artist_id }
              else
                errors_list << { artist_id: artist_id, error: 'Failed to remove' }
              end
            else
              errors_list << { artist_id: artist_id, error: 'Artist not found in this event' }
            end
          end
        end
        
        api_success(
          data: {
            event_id: @event.id,
            removed_count: removed.size,
            removed: removed,
            errors: errors_list
          },
          message: "#{removed.size} artist(s) removed successfully",
          status: :ok
        )
      rescue => e
        Rails.logger.error "Bulk Remove Event Artists Error: #{e.message}"
        api_error(message: 'Failed to bulk remove artists', status: :internal_server_error)
      end
      
      private
      
      def set_event
        @event = Event.find_by(id: params[:event_id])
        unless @event
          api_error(message: 'Event not found', status: :not_found)
          return
        end
      end
      
      def set_event_artist
        @event_artist = @event.event_artists.find_by(id: params[:id])
        unless @event_artist
          api_error(message: 'Event artist not found', status: :not_found)
          return
        end
      end
      
      def check_event_permission
        # Only venue owner, event creator, or admin can manage artists
        # unless @event.creator_id == current_user.id || current_user.role_admin?
        #   api_error(message: 'You do not have permission to manage artists for this event', status: :forbidden)
        #   return
        # end
      end
      
      def event_artist_params
        (params[:event_artist] || params).permit(
          :artist_id,
          :artist_name,
          :scheduled_start_at,
          :scheduled_end_at,
          :timezone,
          :display_order,
          :description,
          :status
        )
      end
      
      def event_artist_response(event_artist)
        artist_payload = if event_artist.artist
          {
            id: event_artist.artist.id,
            name: event_artist.artist.name,
            username: event_artist.artist.username,
            role: event_artist.artist.role,
            avatar_url: event_artist.artist.respond_to?(:avatar_url) && event_artist.artist.avatar_url.present? ? event_artist.artist.avatar_url : default_avatar_url
          }
        else
          {
            id: nil,
            name: event_artist.display_name,
            username: nil,
            role: nil,
            avatar_url: default_avatar_url
          }
        end

        {
          id: event_artist.id,
          event_id: event_artist.event_id,
          artist_id: event_artist.artist_id,
          artist_name: event_artist.artist_name,
          artist: artist_payload,
          schedule: {
            scheduled_start_at: event_artist.scheduled_start_at.iso8601,
            scheduled_end_at: event_artist.scheduled_end_at.iso8601,
            timezone: event_artist.timezone,
            duration_minutes: event_artist.duration_minutes,
            duration_hours: event_artist.duration_hours
          },
          display_order: event_artist.display_order,
          description: event_artist.description,
          status: event_artist.status,
          is_live: event_artist.is_live?,
          is_upcoming: event_artist.is_upcoming?,
          is_past: event_artist.is_past?,
          created_at: event_artist.created_at.iso8601,
          updated_at: event_artist.updated_at.iso8601
        }
      end
    end
  end
end

