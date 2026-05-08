module Api
  module V1
    class ArtistsController < ApplicationController
      before_action :require_authentication!
      before_action :set_artist, only: [:show]
      
      # GET /api/v1/artists
      # List all users with artist role
      def index
        artists = User.artists.active
        
        # Search by name or username
        if params[:search].present?
          search_term = "%#{params[:search].downcase}%"
          artists = artists.where('LOWER(name) LIKE ? OR LOWER(username) LIKE ?', search_term, search_term)
        end
        
        # Filter by category
        if params[:category_id].present?
          artists = artists.joins(:artist_categories).where(artist_categories: { category_id: params[:category_id] })
        end
        
        # Sorting
        case params[:sort]
        when 'name'
          artists = artists.order(name: :asc)
        when 'newest'
          artists = artists.order(created_at: :desc)
        when 'popular'
          # Sort by followers count (if available)
          artists = artists.left_joins(:follows_as_following)
                          .group('users.id')
                          .order('COUNT(follows.id) DESC')
        else
          artists = artists.order(name: :asc)
        end
        
        # Pagination
        limit = [params[:limit]&.to_i || 20, 100].min
        offset = params[:offset]&.to_i || 0
        total_count = artists.count
        total_count = total_count.count if total_count.is_a?(Hash) # Handle grouped count
        artists = artists.limit(limit).offset(offset)
        
        api_success(
          data: {
            artists: artists.map { |artist| artist_response(artist) },
            pagination: {
              total: total_count,
              limit: limit,
              offset: offset,
              has_more: offset + limit < total_count
            }
          },
          status: :ok
        )
      end
      
      # GET /api/v1/artists/:id
      # Get single artist details
      def show
        api_success(
          data: {
            artist: artist_detail_response(@artist)
          },
          status: :ok
        )
      end
      
      # GET /api/v1/artists/:id/events
      # List events where this artist is performing
      def events
        artist = User.artists.find_by(id: params[:id])
        unless artist
          api_error(message: 'Artist not found', status: :not_found)
          return
        end
        
        event_artists = EventArtist.includes(event: :venue)
                                   .where(artist_id: artist.id)
                                   .order('events.starts_at ASC')
        
        # Filter by status
        if params[:status].present?
          event_artists = event_artists.where(status: params[:status])
        end
        
        # Filter upcoming/past
        if params[:filter] == 'upcoming'
          event_artists = event_artists.joins(:event).where('events.starts_at > ?', Time.current)
        elsif params[:filter] == 'past'
          event_artists = event_artists.joins(:event).where('events.ends_at < ?', Time.current)
        end
        
        # Pagination
        limit = [params[:limit]&.to_i || 20, 100].min
        offset = params[:offset]&.to_i || 0
        total_count = event_artists.count
        event_artists = event_artists.limit(limit).offset(offset)
        
        api_success(
          data: {
            artist_id: artist.id,
            artist_name: artist.name,
            events: event_artists.map { |ea| artist_event_response(ea) },
            pagination: {
              total: total_count,
              limit: limit,
              offset: offset,
              has_more: offset + limit < total_count
            }
          },
          status: :ok
        )
      end
      
      # GET /api/v1/artists/:id/categories
      # Get artist's categories
      def categories
        artist = User.artists.find_by(id: params[:id])
        unless artist
          api_error(message: 'Artist not found', status: :not_found)
          return
        end
        
        categories = artist.categories
        
        api_success(
          data: {
            artist_id: artist.id,
            artist_name: artist.name,
            categories: categories.map { |c| { id: c.id, name: c.name } }
          },
          status: :ok
        )
      end
      
      private
      
      def set_artist
        @artist = User.artists.find_by(id: params[:id])
        unless @artist
          api_error(message: 'Artist not found', status: :not_found)
          return
        end
      end
      
      def artist_response(artist)
        follow_status = get_follow_request_status(artist)
        
        {
          id: artist.id,
          name: artist.name,
          username: artist.username,
          role: artist.role,
          bio: artist.bio,
          avatar_url: artist.avatar_url,
          profile_picture_url: artist.profile_picture.attached? ? url_for(artist.profile_picture) : default_avatar_url,
          followers_count: artist.followers.count,
          following_count: artist.following.count,
          categories: artist.categories.map { |c| { id: c.id, name: c.name } },
          is_following: current_user.following.include?(artist),
          has_pending_request_to: follow_status[:has_pending_request_to],
          has_pending_request_from: follow_status[:has_pending_request_from],
          pending_request_id: follow_status[:pending_request_id],
          pending_request_to_id: follow_status[:pending_request_to_id],
          created_at: artist.created_at
        }
      rescue => e
        Rails.logger.error "Artist response error: #{e.message}"
        follow_status = get_follow_request_status(artist)
        {
          id: artist.id,
          name: artist.name,
          username: artist.username,
          role: artist.role,
          bio: artist.bio,
          avatar_url: artist.avatar_url,
          categories: [],
          is_following: false,
          has_pending_request_to: follow_status[:has_pending_request_to],
          has_pending_request_from: follow_status[:has_pending_request_from],
          pending_request_id: follow_status[:pending_request_id],
          pending_request_to_id: follow_status[:pending_request_to_id],
          created_at: artist.created_at
        }
      end
      
      # Get follow request status between current_user and target user
      def get_follow_request_status(target_user)
        return { 
          has_pending_request_to: false, 
          has_pending_request_from: false, 
          pending_request_id: nil,
          pending_request_to_id: nil
        } if target_user == current_user
        
        # Check if current_user sent a pending request to target_user
        pending_request_to = current_user.follow_requests_sent.pending.find_by(requested_id: target_user.id)
        
        # Check if current_user received a pending request from target_user
        pending_request_from = current_user.follow_requests_received.pending.find_by(requester_id: target_user.id)
        
        {
          has_pending_request_to: pending_request_to.present?,
          has_pending_request_from: pending_request_from.present?,
          pending_request_id: pending_request_from&.id,  # ID of request received (for Accept/Reject)
          pending_request_to_id: pending_request_to&.id  # ID of request sent (for Cancel)
        }
      end
      
      def artist_detail_response(artist)
        base = artist_response(artist)
        
        # Add upcoming events count
        upcoming_events_count = EventArtist.where(artist_id: artist.id)
                                           .joins(:event)
                                           .where('events.starts_at > ?', Time.current)
                                           .where(status: 'confirmed')
                                           .count
        
        # Add past events count
        past_events_count = EventArtist.where(artist_id: artist.id)
                                       .joins(:event)
                                       .where('events.ends_at < ?', Time.current)
                                       .count
        
        base.merge(
          upcoming_events_count: upcoming_events_count,
          past_events_count: past_events_count,
          total_events_count: upcoming_events_count + past_events_count,
          phone: artist.phone, # Only include if appropriate
          email: artist.email
        )
      end
      
      def artist_event_response(event_artist)
        event = event_artist.event
        {
          event_artist_id: event_artist.id,
          event: {
            id: event.id,
            title: event.title,
            starts_at: event.starts_at,
            ends_at: event.ends_at,
            venue: {
              id: event.venue.id,
              name: event.venue.name
            }
          },
          schedule: {
            scheduled_start_at: event_artist.scheduled_start_at,
            scheduled_end_at: event_artist.scheduled_end_at,
            timezone: event_artist.timezone,
            duration_minutes: event_artist.duration_minutes
          },
          status: event_artist.status,
          description: event_artist.description,
          is_live: event_artist.is_live?,
          is_upcoming: event_artist.is_upcoming?,
          is_past: event_artist.is_past?
        }
      end
    end
  end
end







