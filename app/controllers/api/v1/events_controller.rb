module Api
  module V1
    class EventsController < ApplicationController
      include PrChatUsersHelpers

      # Preload tier rows for event_response ticket_types (avoid N+1 on lists).
      EVENT_TICKET_TYPES_INCLUDE = :event_ticket_types

      before_action :require_authentication!, except: [:report_reasons, :share_qr, :by_invite]
      before_action :set_event, only: [:show, :update, :destroy, :publish, :cancel, :block, :unblock, :share_qr, :regenerate_invite, :report, :check_report, :upload_photos, :remove_photo, :create_boost, :show_boost, :update_boost, :cancel_boost, :list_boosts, :submit_boost_for_review, :pause_boost, :resume_boost, :list_interests, :mark_interest, :unmark_interest, :toggle_interest, :check_interest, :mark_rsvp, :approve_rsvp, :unmark_rsvp, :check_rsvp, :list_rsvps, :pr_chat_users]
      before_action :authorize_manage_event!, only: [:update, :destroy, :publish, :cancel]
      before_action :authorize_event_share!, only: [:share_qr]
      before_action :set_venue, only: [:venue_events, :create, :last_address]
      
      # GET /api/v1/events
      def index
        # Track if we're using distance filtering (affects includes and ordering)
        using_distance = params[:lat].present? && params[:lng].present?
        
        # When using distance, we need joins instead of includes for the calculation
        if using_distance
          events = Event.joins(:venue)
                        .includes(EVENT_TICKET_TYPES_INCLUDE, :event_artists, venue: :owner, photos_attachments: :blob)
        else
        events = Event.includes(EVENT_TICKET_TYPES_INCLUDE, :venue, :event_artists, venue: :owner, photos_attachments: :blob)
        end
        
        # =====================================================
        # DISTANCE FILTERING
        # =====================================================
        if using_distance
          min_distance = params[:min_distance]&.to_f
          max_distance = params[:max_distance]&.to_f
          
          events = events.within_distance(
            params[:lat].to_f,
            params[:lng].to_f,
            min_distance_km: min_distance,
            max_distance_km: max_distance
          )
        end
        
        # =====================================================
        # DATE AND TIME FILTERING
        # =====================================================
        # Filter by start date/time
        if params[:start_date].present?
          start_date = parse_datetime(params[:start_date])
          events = events.where('starts_at >= ?', start_date) if start_date
        end
        
        # Filter by end date/time
        if params[:end_date].present?
          end_date = parse_datetime(params[:end_date])
          events = events.where('ends_at <= ?', end_date) if end_date
        end
        
        # Filter by date range (events that occur within this range)
        if params[:date_from].present? && params[:date_to].present?
          date_from = parse_datetime(params[:date_from])
          date_to = parse_datetime(params[:date_to])
          if date_from && date_to
            # Events that overlap with the date range
            events = events.where(
              '(starts_at <= ? AND ends_at >= ?)',
              date_to, date_from
            )
          end
        end
        
        # Filter by time of day (hour)
        if params[:time_from].present? || params[:time_to].present?
          time_from = params[:time_from]&.to_i
          time_to = params[:time_to]&.to_i
          
          if time_from.present? && time_to.present?
            # Events that start between these hours (0-23)
            events = events.where(
              'EXTRACT(HOUR FROM starts_at) >= ? AND EXTRACT(HOUR FROM starts_at) <= ?',
              time_from, time_to
            )
          elsif time_from.present?
            events = events.where('EXTRACT(HOUR FROM starts_at) >= ?', time_from)
          elsif time_to.present?
            events = events.where('EXTRACT(HOUR FROM starts_at) <= ?', time_to)
          end
        end
        
        # Filter by time (predefined filters)
        case params[:time_filter]
        when 'upcoming'
          events = events.upcoming
        when 'past'
          events = events.past
        when 'live'
          events = events.live
        end
        
        # =====================================================
        # CATEGORY / TAG FILTERING
        # =====================================================
        # Filter by tag (slug from event_tags: all, festival, party, etc.)
        if params[:tag].present? && params[:tag].to_s.downcase != 'all'
          slug = params[:tag].to_s.parameterize
          event_tag = EventTag.where(slug: slug)
                             .where('country IS NULL OR country = ?', params[:country].to_s)
                             .order(Arel.sql('CASE WHEN country IS NOT NULL THEN 0 ELSE 1 END'))
                             .first
          if event_tag
            if event_tag.category_slug.present?
              # Try new category system first, fallback to legacy
              cat = Category.find_by(slug: event_tag.category_slug)
              if cat
                events = events.by_category_slugs([event_tag.category_slug])
              else
                # Legacy category mapping for default tags
                legacy = { 'festival' => 'Festivals', 'party' => 'Party Events' }[event_tag.slug]
                events = events.where(category: legacy) if legacy
              end
            else
              cat_name = Event::CATEGORIES.find { |c| c.parameterize == event_tag.slug }
              events = events.where(category: cat_name) if cat_name
            end
          end
        end

        # Filter by legacy category (single category field)
        if params[:category].present?
          categories = Array(params[:category])
          unless categories.map(&:downcase).include?('all')
            events = events.where(category: categories)
          end
        end
        
        # Filter by new category IDs (multiple categories system)
        # Note: These scopes add DISTINCT, which can cause issues with SELECT distance_km
        # We'll handle this by ensuring distance is recalculated in ORDER BY if needed
        if params[:category_ids].present?
          events = events.by_category_ids(params[:category_ids])
        end
        
        # Filter by category slugs (multiple categories system)
        if params[:category_slugs].present?
          events = events.by_category_slugs(params[:category_slugs])
        end
        
        # =====================================================
        # OTHER FILTERS
        # =====================================================
        # Filter by venue
        events = events.where(venue_id: params[:venue_id]) if params[:venue_id].present?

        # Filter by ownership
        # owner=me or my_events=true -> only events owned by current user
        # owner=not_me or my_events=false -> exclude current user's venues
        if params[:owner].to_s == 'me' || params[:my_events].to_s == 'true'
          events = events.where(creator_id: current_user.id)
        elsif params[:owner].to_s == 'not_me' || params[:my_events].to_s == 'false'
          events = events.where.not(creator_id: current_user.id)
        end
        
        # Filter by status (explicit list) OR published boolean (published vs draft only)
        # - status=published / status=draft / status[]=... — full control
        # - published=true — only published; published=false — only draft; omit — draft + published (default)
        if params[:status].present?
          statuses = Array(params[:status])
          events = events.where(status: statuses)
        elsif published_filter_param_provided?
          events = events.where(status: published_filter_status)
        else
          events = events.where(status: %w[draft published])
        end
        
        # Search filter
        if params[:search].present?
          search_term = "%#{params[:search]}%"
          events = events.where(
            "title ILIKE ? OR description ILIKE ? OR category ILIKE ?",
            search_term, search_term, search_term
          )
        end
        
        # =====================================================
        # ADD DISTANCE TO SELECT (before sorting if DISTINCT is present)
        # =====================================================
        # When DISTINCT is used, we need distance_km in SELECT for ORDER BY to work
        has_distinct = params[:category_ids].present? || params[:category_slugs].present?
        
        if using_distance && has_distinct
          lat = params[:lat].to_f
          lng = params[:lng].to_f
          distance_calc = "(6371 * acos(LEAST(1.0, cos(radians(#{lat})) * cos(radians(COALESCE(events.latitude, venues.latitude))) * cos(radians(COALESCE(events.longitude, venues.longitude)) - radians(#{lng})) + sin(radians(#{lat})) * sin(radians(COALESCE(events.latitude, venues.latitude))))))"
          # Explicitly list all columns when DISTINCT is present
          event_columns = Event.column_names.map { |col| "events.#{col}" }.join(', ')
          select_sql = "#{event_columns}, #{distance_calc} AS distance_km"
          events = events.select(Arel.sql(select_sql))
        end
        
        # =====================================================
        # SORTING
        # =====================================================
        # Sort by distance if lat/lng provided
        if using_distance
          if has_distinct
            # Use the distance_km alias from SELECT
            events = events.reorder(Arel.sql('distance_km ASC, events.starts_at ASC'))
          else
            # Recalculate distance in ORDER BY since SELECT alias isn't available yet
            lat = params[:lat].to_f
            lng = params[:lng].to_f
            distance_order = <<-SQL.strip
              (6371 * acos(
                LEAST(1.0,
                  cos(radians(#{lat})) *
                  cos(radians(COALESCE(events.latitude, venues.latitude))) *
                  cos(radians(COALESCE(events.longitude, venues.longitude)) - radians(#{lng})) +
                  sin(radians(#{lat})) *
                  sin(radians(COALESCE(events.latitude, venues.latitude)))
                )
              )) ASC, events.starts_at ASC
            SQL
            events = events.reorder(Arel.sql(distance_order))
          end
        else
          events = events.order(starts_at: :asc)
        end
        
        # =====================================================
        # BLOCKED USER FILTERING
        # =====================================================
        # Filter out events created by blocked users (if authenticated)
        if current_user.present?
          events = events.visible_to_user(current_user)
        end
        
        # =====================================================
        # PAGINATION
        # =====================================================
        limit = [params[:limit]&.to_i || 20, 100].min
        
        # Calculate offset: prefer explicit offset, otherwise convert page to offset
        if params[:offset].present?
          offset = params[:offset].to_i
        elsif params[:page].present?
          page = params[:page].to_i
          offset = [(page - 1) * limit, 0].max # Ensure offset is never negative
        else
          offset = 0
        end
        
        # Get total count before pagination
        # Use count(:all) to ensure accurate count even with DISTINCT
        total_count = events.count(:all)
        
        # Apply pagination
        events = events.limit(limit).offset(offset)
        
        # =====================================================
        # ADD DISTANCE TO SELECT (after pagination, if not already added)
        # =====================================================
        # Add distance_km to SELECT clause only if it wasn't added before (for DISTINCT case)
        if using_distance && !has_distinct
          lat = params[:lat].to_f
          lng = params[:lng].to_f
          distance_calc = "(6371 * acos(LEAST(1.0, cos(radians(#{lat})) * cos(radians(COALESCE(events.latitude, venues.latitude))) * cos(radians(COALESCE(events.longitude, venues.longitude)) - radians(#{lng})) + sin(radians(#{lat})) * sin(radians(COALESCE(events.latitude, venues.latitude))))))"
          # No DISTINCT, so events.* should work fine
          select_sql = "events.*, #{distance_calc} AS distance_km"
          events = events.select(Arel.sql(select_sql))
        end
        
        # Build response with distance information if available
        include_attendees = params[:include_attendees].to_s == 'true'
        events_data = events.map do |event|
          response = event_response(event, request: request)
          response[:going] = going_payload(event) if include_attendees
          # Add distance if it was calculated (from SELECT distance_km)
          if event.attributes.key?('distance_km') && event.attributes['distance_km'].present?
            response[:distance_km] = event.attributes['distance_km'].to_f.round(2)
          end
          response
        end
        
        api_success(
          data: {
            events: events_data,
            filters_applied: build_filters_summary,
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
      
      # GET /api/v1/venues/:venue_id/events
      def venue_events
        events = @venue.events.includes(EVENT_TICKET_TYPES_INCLUDE, :venue, venue: :owner, photos_attachments: :blob).order(starts_at: :desc)
        
        limit = [params[:limit]&.to_i || 20, 100].min
        offset = params[:offset]&.to_i || 0
        total_count = events.count
        events = events.limit(limit).offset(offset)
        
        include_attendees = params[:include_attendees].to_s == 'true'
        api_success(
          data: {
            events: events.map { |event| event_response(event, request: request).merge(include_attendees ? { going: going_payload(event) } : {}) },
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
      
      # GET /api/v1/venues/:venue_id/events/last_address
      # Suggests address fields for a new event: most recently updated venue event with any
      # location override; otherwise the venue's default address.
      def last_address
        unless current_user.role_venue_manager? || current_user.role_admin?
          api_error(message: 'Only venue managers can create events', status: :forbidden)
          return
        end
        
        event = @venue.events.with_location_override.order(updated_at: :desc).first
        if event
          api_success(
            data: {
              source: 'last_event',
              event_id: event.id,
              address: last_address_suggestion_payload(event)
            },
            status: :ok
          )
        else
          api_success(
            data: {
              source: 'venue_default',
              event_id: nil,
              address: last_address_suggestion_payload(@venue)
            },
            status: :ok
          )
        end
      end
      
      # GET /api/v1/events/:id
      def show
        api_success(
          data: { event: event_detail_response(@event, request: request, include_attendees: params[:include_attendees]) },
          status: :ok
        )
      end
      
      # POST /api/v1/venues/:venue_id/events
      def create
        unless current_user.role_venue_manager? || current_user.role_admin?
          api_error(message: 'Only venue managers can create events', status: :forbidden)
          return
        end
        
        # unless @venue.owner_id == current_user.id || current_user.role_admin?
        #   api_error(message: 'You do not have permission to create events for this venue', status: :forbidden)
        #   return
        # end
        
        normalize_age_pricing_params!
        normalize_collaborator_params!
        event = @venue.events.build(event_params)
        event.status = 'draft'
        event.creator = current_user
        # Use venue's default currency for event creation when currency not provided
        event.currency = @venue.effective_default_currency if event.currency.blank?
        
        # Set photo URLs if provided
        if params[:photo_urls].present?
          event.photo_urls = Array(params[:photo_urls]).compact
        end

        if should_apply_ticket_types?
          raw = ticket_types_array_from_params
          unless raw.is_a?(Array)
            api_error(message: 'ticket_types must be an array', status: :bad_request)
            return
          end
        end

        begin
          ActiveRecord::Base.transaction do
            event.save!
            apply_event_tags!(event)
            if should_apply_ticket_types?
              event.replace_ticket_types!(ticket_types_array_from_params)
            end
          end
        rescue ActiveRecord::RecordInvalid
          api_validation_error(errors: event.errors.full_messages)
          return
        rescue ArgumentError => e
          api_error(message: e.message, status: :bad_request)
          return
        end

        # Attach poster file if provided (multipart/form-data)
        if params[:poster].present?
          event.poster.attach(params[:poster])
        end

        # Attach photo files if provided (multipart/form-data)
        if params[:photos].present?
          Array(params[:photos]).each do |photo|
            event.photos.attach(photo) if photo.present?
          end
        end

        # Add inline artists if provided (artist_id or artist_name per item)
        add_inline_artists(event)

        # Reload to get attached files
        event.reload

        api_success(
          data: { event: event_detail_response(event, request: request) },
          message: 'Event created successfully',
          status: :created
        )
      rescue => e
        Rails.logger.error "Create Event Error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        api_error(message: 'Failed to create event', status: :internal_server_error)
      end

      # POST /api/v1/events
      # Create an event without requiring a host venue in the URL.
      # Optionally accepts event[venue_id] to attach a venue if the user has permission.
      def create_global
        unless current_user.role_venue_manager? || current_user.role_admin? || current_user.role_brand?
          api_error(message: 'Only venue managers, brands, or admins can create events', status: :forbidden)
          return
        end

        normalize_age_pricing_params!
        normalize_collaborator_params!

        event = Event.new(event_params)
        event.status = 'draft'
        event.creator = current_user
        event.venue = current_user.venues.last if current_user.venues.present?

        # If a venue_id is provided in params, attach the venue after permission check
        if params.dig(:event, :venue_id).present?
          venue = Venue.find_by(id: params[:event][:venue_id])
          unless venue
            api_error(message: 'Venue not found', status: :not_found)
            return
          end

          unless venue.owner_id == current_user.id || current_user.role_admin?
            api_error(message: 'You do not have permission to create events for this venue', status: :forbidden)
            return
          end

          event.venue = venue
          event.currency = venue.effective_default_currency if event.currency.blank?
        end

        # Set photo URLs if provided
        if params[:photo_urls].present?
          event.photo_urls = Array(params[:photo_urls]).compact
        end

        if should_apply_ticket_types?
          raw = ticket_types_array_from_params
          unless raw.is_a?(Array)
            api_error(message: 'ticket_types must be an array', status: :bad_request)
            return
          end
        end

        begin
          ActiveRecord::Base.transaction do
            event.save!
            apply_event_tags!(event)
            if should_apply_ticket_types?
              event.replace_ticket_types!(ticket_types_array_from_params)
            end
          end
        rescue ActiveRecord::RecordInvalid
          api_validation_error(errors: event.errors.full_messages)
          return
        rescue ArgumentError => e
          api_error(message: e.message, status: :bad_request)
          return
        end

        # Attach poster file if provided (multipart/form-data)
        if params[:poster].present?
          event.poster.attach(params[:poster])
        end

        # Attach photo files if provided (multipart/form-data)
        if params[:photos].present?
          Array(params[:photos]).each do |photo|
            event.photos.attach(photo) if photo.present?
          end
        end

        # Add inline artists if provided (artist_id or artist_name per item)
        add_inline_artists(event)

        event.reload

        api_success(
          data: { event: event_detail_response(event, request: request) },
          message: 'Event created successfully',
          status: :created
        )
      rescue => e
        Rails.logger.error "Create Global Event Error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        api_error(message: 'Failed to create event', status: :internal_server_error)
      end
      
      # GET /api/v1/events/:id/pr_chat_users
      # Also: GET /api/v1/events/:event_id/pr_chat_users (set_event accepts event_id)
      # Lists active PR users for the host venue so guests and staff can start 1:1 chats (POST /api/v1/chats).
      def pr_chat_users
        return if performed?

        unless can_access_event_pr_chat_users?(@event)
          api_error(message: 'You do not have access to PR contacts for this event', status: :forbidden)
          return
        end

        payload = pr_chat_users_payload_for_venue(@event.venue)
        success_opts = {
          data: payload.merge(event_id: @event.id.to_s),
          status: :ok
        }
        success_opts[:message] = 'No active PR users for this event’s venue' unless payload[:pr_users].any?
        api_success(**success_opts)
      end

      # PATCH /api/v1/events/:id
      def update
        # Remove poster if requested
        if params[:remove_poster] == 'true' || params[:remove_poster] == true
          @event.poster.purge if @event.poster.attached?
        end
        
        # Remove photos if requested
        if params[:remove_photo_ids].present?
          photo_ids = Array(params[:remove_photo_ids])
          @event.photos.where(id: photo_ids).purge
        end
        
        # Update photo URLs if provided
        if params[:photo_urls].present?
          @event.photo_urls = Array(params[:photo_urls]).compact
        end
        
        normalize_age_pricing_params!
        normalize_collaborator_params!

        if should_apply_ticket_types?
          raw = ticket_types_array_from_params
          unless raw.is_a?(Array)
            api_error(message: 'ticket_types must be an array', status: :bad_request)
            return
          end
        end

        begin
          ActiveRecord::Base.transaction do
            @event.update!(event_params)
            if should_apply_ticket_types?
              @event.replace_ticket_types!(ticket_types_array_from_params)
            end
          end
        rescue ActiveRecord::RecordInvalid
          api_validation_error(errors: @event.errors.full_messages)
          return
        rescue ArgumentError => e
          api_error(message: e.message, status: :bad_request)
          return
        end

        # Attach/replace poster file if provided (multipart/form-data)
        if params[:poster].present?
          @event.poster.purge if @event.poster.attached? # Replace existing
          @event.poster.attach(params[:poster])
        end

        # Add new photo files if provided (multipart/form-data)
        if params[:photos].present?
          Array(params[:photos]).each do |photo|
            @event.photos.attach(photo) if photo.present?
          end
        end

        @event.reload

        api_success(
          data: { event: event_detail_response(@event, request: request) },
          message: 'Event updated successfully',
          status: :ok
        )
      rescue => e
        Rails.logger.error "Update Event Error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        api_error(message: 'Failed to update event', status: :internal_server_error)
      end
      
      # DELETE /api/v1/events/:id
      def destroy
        if @event.destroy
          api_success(
            message: 'Event deleted successfully',
            status: :ok
          )
        else
          api_error(
            message: 'Failed to delete event',
            status: :unprocessable_entity
          )
        end
      end
      
      # POST /api/v1/events/:id/publish
      # Handles both publish and unpublish via action param.
      # Params: action: 'publish' | 'unpublish' (default: 'publish' or toggle from current state)
      def publish
        action = (params[:publish_action] || params[:action] || 'publish').to_s.downcase

        target_status = if action == 'unpublish'
          'draft'
        else
          'published'
        end

        if @event.update(status: target_status)
          api_success(
            data: { event: event_detail_response(@event, request: request) },
            message: target_status == 'published' ? 'Event published successfully' : 'Event unpublished successfully',
            status: :ok
          )
        else
          api_validation_error(errors: @event.errors.full_messages)
        end
      end
      
      # POST /api/v1/events/:id/cancel
      def cancel
        if @event.update(status: 'canceled')
          # TODO: Notify all attendees about cancellation
          api_success(
            data: { event: event_detail_response(@event, request: request) },
            message: 'Event canceled successfully',
            status: :ok
          )
        else
          api_validation_error(errors: @event.errors.full_messages)
        end
      end
      
      # POST /api/v1/events/:id/block
      def block
        unless current_user.role_admin?
          api_error(message: 'Only admins can block events', status: :forbidden)
          return
        end
        
        if @event.update(status: 'blocked')
          api_success(
            data: { event: event_detail_response(@event, request: request) },
            message: 'Event blocked successfully',
            status: :ok
          )
        else
          api_validation_error(errors: @event.errors.full_messages)
        end
      end
      
      # POST /api/v1/events/:id/unblock
      def unblock
        unless current_user.role_admin?
          api_error(message: 'Only admins can unblock events', status: :forbidden)
          return
        end
        
        if @event.update(status: 'published')
          api_success(
            data: { event: event_detail_response(@event, request: request) },
            message: 'Event unblocked successfully',
            status: :ok
          )
        else
          api_validation_error(errors: @event.errors.full_messages)
        end
      end
      
      # GET /api/v1/events/by_invite?token= (public — validate invite link for private events)
      def by_invite
        token = params[:token].to_s.strip
        if token.blank?
          api_error(message: 'token is required', status: :bad_request)
          return
        end

        event = Event.published.find_by(invite_token: token)
        unless event
          api_error(message: 'Invalid or expired invite', status: :not_found)
          return
        end

        api_success(
          data: {
            event_id: event.id,
            title: event.title,
            starts_at: event.starts_at,
            ends_at: event.ends_at,
            timezone: event.timezone,
            visibility: event.visibility,
            venue: event.venue ? { id: event.venue.id, name: event.venue.name, city: event.venue.city, country: event.venue.country } : nil
          },
          status: :ok
        )
      end

      # POST /api/v1/events/:id/regenerate_invite — host only; invalidates old invite links
      def regenerate_invite
        unless current_user
          api_error(message: 'Unauthorized', status: :unauthorized)
          return
        end

        unless @event.creator_id == current_user.id || @event.venue&.owner_id == current_user.id || current_user.role_admin?
          api_error(message: 'Only the event host or venue owner can regenerate the invite', status: :forbidden)
          return
        end

        unless @event.visibility_private? || @event.visibility_unlisted?
          api_error(message: 'Invite links are only used for private or unlisted events', status: :unprocessable_entity)
          return
        end

        @event.regenerate_invite_token!
        base = request.base_url
        api_success(
          data: invite_payload(@event, base_url: base),
          message: 'Invite link regenerated. Previous links no longer work.',
          status: :ok
        )
      end

      # GET /api/v1/events/:id/share_qr
      def share_qr
        require 'rqrcode'

        if @event.visibility_private? || @event.visibility_unlisted?
          @event.ensure_invite_token!
        end

        event_url = if @event.invite_token.present?
                      "vibes://events/#{@event.id}?invite=#{@event.invite_token}"
                    else
                      "vibes://events/#{@event.id}"
                    end

        qr_data = {
          type: 'Event',
          event_id: @event.id,
          url: event_url
        }
        qr_data[:invite_token] = @event.invite_token if @event.invite_token.present?
        qr = RQRCode::QRCode.new(qr_data.to_json)
        
        # Get size parameter (default: 300)
        size = params[:size].to_i
        size = 300 if size <= 0 || size > 1000 # Limit between 1 and 1000
        
        # Convert to PNG
        png = qr.as_png(
          bit_depth: 1,
          border_modules: 4,
          color_mode: ChunkyPNG::COLOR_GRAYSCALE,
          color: 'black',
          file: nil,
          fill: 'white',
          module_px_size: 6,
          resize_exactly_to: false,
          resize_gte_to: false,
          size: size
        )
        
        # If format=image, return PNG image directly
        if params[:format] == 'image'
          send_data png.to_s, 
                    type: 'image/png', 
                    disposition: 'inline',
                    filename: "event_#{@event.id}_qr.png"
          return
        end
        
        # Otherwise, return JSON with base64 encoded QR code
        base = request.base_url
        api_success(
          data: {
            qr_code: Base64.strict_encode64(png.to_s),
            qr_image_url: "#{base}/api/v1/events/#{@event.id}/share_qr?format=image&size=#{size}",
            event_url: event_url,
            type: 'Event',
            event_id: @event.id,
            invite: (@event.invite_token.present? ? invite_payload(@event, base_url: base) : nil),
            event: event_response(@event, request: request)
          },
          status: :ok
        )
      end
      
      # =====================================================
      # SIMPLE INTEREST (Boolean - no RSVP status)
      # =====================================================
      
      # POST /api/v1/events/:event_id/interests
      # Mark simple interest (boolean - no RSVP status)
      def mark_interest
        return if performed? # Stop if set_event failed
        
        # Check if user already has an RSVP (with status)
        existing_rsvp = current_user.event_interests.where(event: @event).where.not(rsvp_status: nil).first
        if existing_rsvp
          api_error(message: 'You already have an RSVP for this event. Remove RSVP first to mark simple interest.', status: :bad_request)
          return
        end
        
        # Create simple interest (no rsvp_status)
        interest = current_user.event_interests.find_or_initialize_by(event: @event, rsvp_status: nil)
        
        if interest.save
          api_success(
            data: {
              interest: {
                id: interest.id,
                interested: true,
                created_at: interest.created_at
              },
              interests_count: @event.event_interests.where(rsvp_status: nil).count
            },
            message: 'Interest marked successfully',
            status: interest.persisted_before_last_save? ? :ok : :created
          )
        else
          api_validation_error(errors: interest.errors.full_messages)
        end
      end
      
      # DELETE /api/v1/events/:event_id/interests
      # Remove simple interest
      def unmark_interest
        return if performed? # Stop if set_event failed
        interest = current_user.event_interests.find_by(event: @event, rsvp_status: nil)
        
        if interest&.destroy
          api_success(
            data: {
              interests_count: @event.event_interests.where(rsvp_status: nil).count
            },
            message: 'Interest removed successfully',
            status: :ok
          )
        else
          api_error(message: 'Interest not found', status: :not_found)
        end
      end
      
      # POST /api/v1/events/:event_id/interests/toggle
      # Toggle simple interest (mark if not interested, remove if interested)
      def toggle_interest
        return if performed? # Stop if set_event failed
        
        # Check if user already has an RSVP (with status)
        existing_rsvp = current_user.event_interests.where(event: @event).where.not(rsvp_status: nil).first
        if existing_rsvp
          api_error(message: 'You already have an RSVP for this event. Remove RSVP first to toggle simple interest.', status: :bad_request)
          return
        end
        
        # Find existing simple interest
        interest = current_user.event_interests.find_by(event: @event, rsvp_status: nil)
        
        if interest
          # Store interest data before destroying
          interest_id = interest.id
          interest_created_at = interest.created_at
          # Remove interest
          interest.destroy
          interested = false
          message = 'Interest removed successfully'
          interest_data = nil
        else
          # Create interest
          interest = current_user.event_interests.create(event: @event, rsvp_status: nil)
          interested = true
          message = 'Interest marked successfully'
          interest_data = {
            id: interest.id,
            created_at: interest.created_at
          }
        end
        
        @event.reload # Reload to get updated counts
        
        api_success(
          data: {
            interested: interested,
            interest: interest_data,
            interests_count: @event.event_interests.where(rsvp_status: nil).count
          },
          message: message,
          status: :ok
        )
      end
      
      # GET /api/v1/events/:event_id/interests/check
      # Check simple interest status
      def check_interest
        return if performed? # Stop if set_event failed
        interest = current_user.event_interests.find_by(event: @event, rsvp_status: nil)
        
        api_success(
          data: {
            interested: interest.present?
          },
          status: :ok
        )
      end
      
      # GET /api/v1/events/:event_id/interests
      # List all simple interests (no RSVP status)
      def list_interests
        return if performed? # Stop if set_event failed
        interests = @event.event_interests.includes(:user).where(rsvp_status: nil)
        
        limit = [params[:limit]&.to_i || 20, 100].min
        offset = params[:offset]&.to_i || 0
        total_count = interests.count
        interests = interests.order(created_at: :desc).limit(limit).offset(offset)
        
        api_success(
          data: {
            event_id: @event.id,
            event_title: @event.title,
            interests: interests.map do |interest|
              {
                id: interest.id,
                user: user_basic_response(interest.user),
                created_at: interest.created_at
              }
            end,
            interests_count: total_count,
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
      
      # =====================================================
      # RSVP / JOIN (Full RSVP with status yes/no/maybe)
      # =====================================================
      
      # POST /api/v1/events/:event_id/rsvp
      # RSVP/Join an event with status (yes/no/maybe), guest count, and notes
      def mark_rsvp
        return if performed? # Stop if set_event failed

        unless @event.rsvp_changes_allowed?
          msg = if !@event.venue_rsvp_enabled?
                  'RSVP is disabled for this venue until the event ends'
                else
                  'This event has ended; RSVP is no longer available'
                end
          api_error(message: msg, status: :forbidden)
          return
        end
        
        rsvp_status = params[:rsvp_status] || 'yes'
        guest_count = params[:guest_count]&.to_i || 0
        notes = params[:notes]
        
        # Check if user has simple interest (no RSVP status) - convert it to RSVP
        simple_interest = current_user.event_interests.find_by(event: @event, rsvp_status: nil)
        if simple_interest
          # Convert simple interest to RSVP
          simple_interest.rsvp_status = rsvp_status
          simple_interest.guest_count = guest_count
          simple_interest.notes = notes if notes.present?
          interest = simple_interest
        else
          # Check if user already has an RSVP - update it
          existing_rsvp = current_user.event_interests.where(event: @event).where.not(rsvp_status: nil).first
          if existing_rsvp
            # Update existing RSVP
            existing_rsvp.rsvp_status = rsvp_status
            existing_rsvp.guest_count = guest_count
            existing_rsvp.notes = notes if notes.present?
            interest = existing_rsvp
          else
            # Create new RSVP
            interest = current_user.event_interests.build(event: @event)
            interest.rsvp_status = rsvp_status
            interest.guest_count = guest_count
            interest.notes = notes if notes.present?
          end
        end
        
        if interest.save
          api_success(
            data: {
              rsvp: {
                id: interest.id,
                rsvp_status: interest.rsvp_status,
                guest_count: interest.guest_count,
                total_attendees: interest.total_attendees,
                notes: interest.notes,
                responded_at: interest.responded_at,
                created_at: interest.created_at
              },
              rsvp_stats: {
                yes_count: @event.event_interests.attending.sum { |i| i.total_attendees || 1 },
                no_count: @event.event_interests.not_attending.count,
                maybe_count: @event.event_interests.maybe_attending.sum { |i| i.total_attendees || 1 },
                total_count: @event.event_interests.where.not(rsvp_status: nil).count
              }
            },
            message: 'RSVP updated successfully',
            status: interest.previously_new_record? ? :created : :ok
          )
        else
          api_validation_error(errors: interest.errors.full_messages)
        end
      end

      # POST /api/v1/events/:event_id/rsvp/approve
      # User-level RSVP approval (intent only)
      def approve_rsvp
        return if performed?

        unless @event.rsvp_changes_allowed?
          msg = if !@event.venue_rsvp_enabled?
                  'RSVP is disabled for this venue until the event ends'
                else
                  'This event has ended; RSVP is no longer available'
                end
          api_error(message: msg, status: :forbidden)
          return
        end

        guest_count = params[:guest_count]&.to_i || 0
        notes = params[:notes]

        rsvp = current_user.event_interests.where(event: @event).where.not(rsvp_status: nil).first
        if rsvp
          rsvp.rsvp_status = 'yes'
          rsvp.guest_count = guest_count
          rsvp.notes = notes if notes.present?
        else
          rsvp = current_user.event_interests.build(event: @event)
          rsvp.rsvp_status = 'yes'
          rsvp.guest_count = guest_count
          rsvp.notes = notes if notes.present?
        end

        unless rsvp.save
          api_validation_error(errors: rsvp.errors.full_messages)
          return
        end

        api_success(
          data: {
            rsvp: {
              id: rsvp.id,
              rsvp_status: rsvp.rsvp_status,
              guest_count: rsvp.guest_count,
              total_attendees: rsvp.total_attendees,
              notes: rsvp.notes,
              responded_at: rsvp.responded_at,
              created_at: rsvp.created_at
            },
            rsvp_stats: {
              yes_count: @event.event_interests.attending.sum { |i| i.total_attendees || 1 },
              no_count: @event.event_interests.not_attending.count,
              maybe_count: @event.event_interests.maybe_attending.sum { |i| i.total_attendees || 1 },
              total_count: @event.event_interests.where.not(rsvp_status: nil).count
            }
          },
          message: 'RSVP approved successfully',
          status: :ok
        )
      end
      
      # DELETE /api/v1/events/:event_id/rsvp
      # Remove RSVP (but keep simple interest if it existed)
      def unmark_rsvp
        return if performed? # Stop if set_event failed
        rsvp = current_user.event_interests.where(event: @event).where.not(rsvp_status: nil).first
        
        if rsvp&.destroy
          api_success(
            data: {
              rsvp_stats: {
                yes_count: @event.event_interests.attending.sum { |i| i.total_attendees || 1 },
                no_count: @event.event_interests.not_attending.count,
                maybe_count: @event.event_interests.maybe_attending.sum { |i| i.total_attendees || 1 },
                total_count: @event.event_interests.where.not(rsvp_status: nil).count
              }
            },
            message: 'RSVP removed successfully',
            status: :ok
          )
        else
          api_error(message: 'RSVP not found', status: :not_found)
        end
      end
      
      # GET /api/v1/events/:event_id/rsvp/check
      # Check RSVP status for current user
      def check_rsvp
        return if performed? # Stop if set_event failed
        rsvp = current_user.event_interests.where(event: @event).where.not(rsvp_status: nil).first
        
        api_success(
          data: {
            has_rsvp: rsvp.present?,
            rsvp_status: rsvp&.rsvp_status,
            guest_count: rsvp&.guest_count,
            total_attendees: rsvp&.total_attendees,
            notes: rsvp&.notes,
            responded_at: rsvp&.responded_at
          },
          status: :ok
        )
      end
      
      # GET /api/v1/events/:event_id/rsvp
      # List all RSVPs (with status) for an event
      def list_rsvps
        return if performed? # Stop if set_event failed
        rsvps = @event.event_interests.includes(:user).where.not(rsvp_status: nil)
        
        # Filter by RSVP status if provided
        if params[:rsvp_status].present?
          rsvps = rsvps.where(rsvp_status: params[:rsvp_status])
        end
        
        limit = [params[:limit]&.to_i || 20, 100].min
        offset = params[:offset]&.to_i || 0
        total_count = rsvps.count
        rsvps = rsvps.order(created_at: :desc).limit(limit).offset(offset)
        
        api_success(
          data: {
            event_id: @event.id,
            event_title: @event.title,
            rsvps: rsvps.map do |rsvp|
              {
                id: rsvp.id,
                user: user_basic_response(rsvp.user),
                rsvp_status: rsvp.rsvp_status,
                guest_count: rsvp.guest_count,
                total_attendees: rsvp.total_attendees,
                notes: rsvp.notes,
                responded_at: rsvp.responded_at,
                created_at: rsvp.created_at
              }
            end,
            rsvp_stats: {
              yes_count: @event.event_interests.attending.sum { |i| i.total_attendees || 1 },
              no_count: @event.event_interests.not_attending.count,
              maybe_count: @event.event_interests.maybe_attending.sum { |i| i.total_attendees || 1 },
              total_count: @event.event_interests.where.not(rsvp_status: nil).count
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

      # GET /api/v1/events/report_reasons
      def report_reasons
        reasons = EventReport::REASONS.map do |reason|
          {
            value: reason,
            label: reason.humanize
          }
        end
        
        api_success(
          data: { reasons: reasons },
          status: :ok
        )
      end
      
      # POST /api/v1/events/:id/report
      def report
        return if performed? # Stop if set_event failed
        
        reason = params[:reason]
        description = params[:description]
        
        if reason.blank?
          api_error(message: 'Reason is required', status: :bad_request)
          return
        end
        
        report = @event.event_reports.build(
          reporter: current_user,
          reason: reason,
          description: description,
          status: 'pending'
        )
        
        if report.save
          api_success(
            message: 'Event reported successfully',
            status: :ok
          )
        else
          api_validation_error(errors: report.errors.full_messages)
        end
      end
      
      # GET /api/v1/events/:id/reports/check
      def check_report
        return if performed? # Stop if set_event failed
        
        reported = @event.event_reports.exists?(reporter: current_user)
        
        api_success(
          data: { reported: reported },
          status: :ok
        )
      end
      
      # GET /api/v1/events/:id/category/check
      def check_category
        event = Event.find(params[:id])
        category_id = params[:category_id]
        
        if category_id.blank?
          api_error(message: 'Category ID is required', status: :bad_request)
          return
        end
        
        # Check if event belongs to category
        # This depends on your Event-Category association
        belongs_to_category = event.categories.exists?(id: category_id) rescue false
        
        api_success(
          data: { belongs_to_category: belongs_to_category },
          status: :ok
        )
      end
      
      # GET /api/v1/events/categories
      # Returns categories sorted by "most used" for the current user:
      # - Venue manager / admin: by events created at their venues
      # - Normal user / artist: by their bookings
      def categories
        sorted = event_categories_sorted_by_usage
        api_success(
          data: {
            categories: sorted
          },
          status: :ok
        )
      end
      
      # GET /api/v1/events/categories/:category/events
      def events_by_category
        category = params[:category].to_s

        if category.blank?
          api_error(message: 'Category is required', status: :bad_request)
          return
        end

        # Allow special "All" category to return all published events
        if category.downcase == 'all'
          events = Event.includes(EVENT_TICKET_TYPES_INCLUDE, :venue, :event_artists, photos_attachments: :blob)
                        .where(status: 'published')
                        .order(starts_at: :asc)
        else
          unless Event::CATEGORIES.include?(category)
            api_error(message: 'Invalid category', status: :bad_request)
            return
          end

          events = Event.includes(EVENT_TICKET_TYPES_INCLUDE, :venue, :event_artists, photos_attachments: :blob)
                        .where(status: 'published', category: category)
                        .order(starts_at: :asc)
        end
        
        limit = [params[:limit]&.to_i || 20, 100].min
        offset = params[:offset]&.to_i || 0
        total_count = events.count
        events = events.limit(limit).offset(offset)
        
        api_success(
          data: {
            category: category,
            events: events.map { |event| event_response(event, request: request) },
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
      
      # POST /api/v1/events/:id/photos
      # Upload multiple images to an event
      def upload_photos
        return if performed? # Stop if set_event failed
        
        # unless can_manage_event?(@event)
        #   api_error(message: 'You do not have permission to upload photos to this event', status: :forbidden)
        #   return
        # end
        
        if params[:photos].blank?
          api_error(message: 'At least one photo file is required', status: :bad_request)
          return
        end
        
        # Validate total count won't exceed limit
        current_count = @event.photos_count
        new_files = Array(params[:photos]).compact
        total_count = current_count + new_files.length
        
        if total_count > 10
          api_error(message: "Cannot upload more than 10 photos total. Current: #{current_count}, Trying to add: #{new_files.length}", status: :bad_request)
          return
        end
        
        # Validate and attach each file
        uploaded_count = 0
        errors = []
        
        new_files.each do |photo|
          # Validate file type
          unless photo.content_type.in?(%w[image/jpeg image/jpg image/png image/gif image/webp])
            errors << "Invalid file type for #{photo.original_filename}. Only JPEG, PNG, GIF, and WebP are allowed"
            next
          end
          
          # Validate file size
          if photo.size > 10.megabytes
            errors << "File #{photo.original_filename} is too large. Maximum size is 10MB"
            next
          end
          
          begin
            @event.photos.attach(photo)
            uploaded_count += 1
          rescue => e
            errors << "Failed to upload #{photo.original_filename}: #{e.message}"
          end
        end
        
        @event.reload
        
        if uploaded_count > 0
          api_success(
            data: {
              event: event_detail_response(@event),
              uploaded_count: uploaded_count,
              total_photos: @event.photos_count,
              errors: errors.any? ? errors : nil
            },
            message: "#{uploaded_count} photo(s) uploaded successfully#{errors.any? ? '. Some files failed to upload' : ''}",
            status: :ok
          )
        else
          api_error(
            message: 'Failed to upload photos',
            data: { errors: errors },
            status: :bad_request
          )
        end
      rescue => e
        Rails.logger.error "Upload Photos Error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        api_error(message: 'Failed to upload photos', status: :internal_server_error)
      end
      
      # DELETE /api/v1/events/:id/photos/:photo_id
      # Remove a photo from an event
      def remove_photo
        return if performed? # Stop if set_event failed
        
        # unless can_manage_event?(@event)
        #   api_error(message: 'You do not have permission to remove photos from this event', status: :forbidden)
        #   return
        # end
        
        photo = @event.photos.find_by(id: params[:photo_id])
        
        unless photo
          api_error(message: 'Photo not found', status: :not_found)
          return
        end
        
        photo.purge
        
        @event.reload
        
        api_success(
          data: {
            event: event_detail_response(@event),
            message: 'Photo removed successfully'
          },
          status: :ok
        )
      rescue => e
        Rails.logger.error "Remove Photo Error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        api_error(message: 'Failed to remove photo', status: :internal_server_error)
      end
      
      # GET /api/v1/events/:event_id/categories
      # List all categories with subscribed flag for an event (like artist categories)
      def event_categories
        event = Event.find_by(id: params[:event_id])
        unless event
          api_error(message: 'Event not found', status: :not_found)
          return
        end
        
        # Get all categories with their groups
        all_categories = Category.includes(:categories_group)
                                 .joins(:categories_group)
                                 .order('categories_groups.display_order, categories.display_order')
        
        # Get event's subscribed category IDs for efficient lookup
        subscribed_category_ids = event.event_categories.pluck(:category_id).to_set
        
        # Group categories by their category group
        categories_by_group = all_categories.group_by(&:categories_group)
        
        # Build response with all categories and subscribed flag
        categories_groups_data = categories_by_group.map do |group, categories|
          {
            id: group.id,
            name: group.name,
            slug: group.slug,
            description: group.description,
            display_order: group.display_order,
            categories: categories.map do |category|
              {
                id: category.id,
                categories_group_id: category.categories_group_id,
                name: category.name,
                slug: category.slug,
                icon_key: category.icon_key,
                display_order: category.display_order,
                subscribed: subscribed_category_ids.include?(category.id)
              }
            end
          }
        end
        
        # Also include flat list of all categories for backward compatibility
        all_categories_flat = all_categories.map do |category|
          {
            id: category.id,
            categories_group_id: category.categories_group_id,
            name: category.name,
            slug: category.slug,
            icon_key: category.icon_key,
            display_order: category.display_order,
            subscribed: subscribed_category_ids.include?(category.id)
          }
        end
        
        api_success(
          data: {
            event_id: event.id,
            event_title: event.title,
            legacy_category: event.category,
            categories_groups: categories_groups_data,
            categories: all_categories_flat,
            subscribed_category_ids: subscribed_category_ids.to_a
          },
          status: :ok
        )
      end
      
      # PUT /api/v1/events/:event_id/categories
      # Replace all categories for an event
      def replace_event_categories
        event = Event.find_by(id: params[:event_id])
        unless event
          api_error(message: 'Event not found', status: :not_found)
          return
        end
        
        # unless can_manage_event?(event)
        #   api_error(message: 'You do not have permission to manage this event', status: :forbidden)
        #   return
        # end
        
        category_ids = Array(params[:category_ids]).map(&:to_s).reject(&:blank?)
        
        if category_ids.empty?
          api_error(message: 'At least one category_id is required', status: :bad_request)
          return
        end
        
        # Validate all categories exist
        existing_ids = Category.where(id: category_ids).pluck(:id)
        missing_ids = category_ids - existing_ids.map(&:to_s)
        if missing_ids.any?
          api_error(message: "Invalid category IDs: #{missing_ids.join(', ')}", status: :bad_request)
          return
        end
        
        if event.replace_categories(category_ids, source: params[:source] || 'manual')
          api_success(
            data: {
              event_id: event.id,
              categories: event.reload.all_categories,
              category_ids: event.category_ids
            },
            message: 'Categories updated successfully',
            status: :ok
          )
        else
          api_error(message: 'Failed to update categories', status: :internal_server_error)
        end
      end
      
      # POST /api/v1/events/:event_id/categories/add
      # Add categories to an event
      def add_event_categories
        event = Event.find_by(id: params[:event_id])
        unless event
          api_error(message: 'Event not found', status: :not_found)
          return
        end
        
        # unless can_manage_event?(event)
        #   api_error(message: 'You do not have permission to manage this event', status: :forbidden)
        #   return
        # end
        
        category_ids = Array(params[:category_ids]).map(&:to_s).reject(&:blank?)
        
        if category_ids.empty?
          api_error(message: 'At least one category_id is required', status: :bad_request)
          return
        end
        
        # Validate all categories exist
        existing_ids = Category.where(id: category_ids).pluck(:id)
        missing_ids = category_ids - existing_ids.map(&:to_s)
        if missing_ids.any?
          api_error(message: "Invalid category IDs: #{missing_ids.join(', ')}", status: :bad_request)
          return
        end
        
        added = []
        skipped = []
        category_ids.each do |cat_id|
          if event.add_category(cat_id, source: params[:source] || 'manual')
            added << cat_id
          else
            skipped << cat_id
          end
        end
        
        api_success(
          data: {
            event_id: event.id,
            added_category_ids: added,
            skipped_category_ids: skipped,
            categories: event.reload.all_categories,
            category_ids: event.category_ids
          },
          message: "#{added.length} category(ies) added#{skipped.any? ? ", #{skipped.length} already existed" : ''}",
          status: :ok
        )
      end
      
      # POST /api/v1/events/:event_id/categories/remove
      # Remove categories from an event
      def remove_event_categories
        event = Event.find_by(id: params[:event_id])
        unless event
          api_error(message: 'Event not found', status: :not_found)
          return
        end
        
        # unless can_manage_event?(event)
        #   api_error(message: 'You do not have permission to manage this event', status: :forbidden)
        #   return
        # end
        
        category_ids = Array(params[:category_ids]).map(&:to_s).reject(&:blank?)
        
        if category_ids.empty?
          api_error(message: 'At least one category_id is required', status: :bad_request)
          return
        end
        
        removed = []
        not_found = []
        category_ids.each do |cat_id|
          if event.remove_category(cat_id)
            removed << cat_id
          else
            not_found << cat_id
          end
        end
        
        api_success(
          data: {
            event_id: event.id,
            removed_category_ids: removed,
            not_found_category_ids: not_found,
            categories: event.reload.all_categories,
            category_ids: event.category_ids
          },
          message: "#{removed.length} category(ies) removed#{not_found.any? ? ", #{not_found.length} not found" : ''}",
          status: :ok
        )
      end

      # =====================================================
      # EVENT CUSTOM CATEGORIES ENDPOINTS
      # =====================================================

      # GET /api/v1/events/:event_id/custom_categories
      # List all custom categories for an event
      def list_custom_categories
        event = Event.find_by(id: params[:event_id])
        unless event
          api_error(message: 'Event not found', status: :not_found)
          return
        end

        custom_categories = event.event_custom_categories.ordered

        api_success(
          data: {
            event_id: event.id,
            custom_categories: custom_categories.map { |cc| custom_category_response(cc) }
          },
          status: :ok
        )
      end

      # POST /api/v1/events/:event_id/custom_categories
      # Add multiple custom categories to an event
      def create_custom_categories
        event = Event.find_by(id: params[:event_id])
        unless event
          api_error(message: 'Event not found', status: :not_found)
          return
        end

        # unless can_manage_event?(event)
        #   api_error(message: 'You do not have permission to manage this event', status: :forbidden)
        #   return
        # end

        custom_categories_data = Array(params[:custom_categories])
        
        if custom_categories_data.empty?
          api_error(message: 'At least one custom category is required', status: :bad_request)
          return
        end

        created = []
        errors = []

        custom_categories_data.each do |cc_data|
          name = cc_data[:name] || cc_data['name']
          description = cc_data[:description] || cc_data['description']

          if name.blank?
            errors << { category: cc_data, error: 'Name is required' }
            next
          end

          custom_category = event.event_custom_categories.build(
            name: name,
            description: description
          )

          if custom_category.save
            created << custom_category_response(custom_category)
          else
            errors << { category: cc_data, errors: custom_category.errors.full_messages }
          end
        end

        api_success(
          data: {
            event_id: event.id,
            created: created,
            errors: errors.any? ? errors : nil,
            total_custom_categories: event.reload.event_custom_categories.count
          },
          message: "#{created.length} custom categor#{created.length == 1 ? 'y' : 'ies'} created#{errors.any? ? ", #{errors.length} failed" : ''}",
          status: :created
        )
      end

      # PATCH /api/v1/events/:event_id/custom_categories/:id
      # Update a custom category
      def update_custom_category
        event = Event.find_by(id: params[:event_id])
        unless event
          api_error(message: 'Event not found', status: :not_found)
          return
        end

        # unless can_manage_event?(event)
        #   api_error(message: 'You do not have permission to manage this event', status: :forbidden)
        #   return
        # end

        custom_category = event.event_custom_categories.find_by(id: params[:id])
        unless custom_category
          api_error(message: 'Custom category not found', status: :not_found)
          return
        end

        if custom_category.update(custom_category_params)
          api_success(
            data: {
              custom_category: custom_category_response(custom_category)
            },
            message: 'Custom category updated successfully',
            status: :ok
          )
        else
          api_validation_error(errors: custom_category.errors.full_messages)
        end
      end

      # DELETE /api/v1/events/:event_id/custom_categories/:id
      # Delete a custom category
      def destroy_custom_category
        event = Event.find_by(id: params[:event_id])
        unless event
          api_error(message: 'Event not found', status: :not_found)
          return
        end

        # unless can_manage_event?(event)
        #   api_error(message: 'You do not have permission to manage this event', status: :forbidden)
        #   return
        # end

        custom_category = event.event_custom_categories.find_by(id: params[:id])
        unless custom_category
          api_error(message: 'Custom category not found', status: :not_found)
          return
        end

        if custom_category.destroy
          api_success(
            message: 'Custom category deleted successfully',
            status: :ok
          )
        else
          api_error(message: 'Failed to delete custom category', status: :unprocessable_entity)
        end
      end

      # DELETE /api/v1/events/:event_id/custom_categories
      # Delete multiple custom categories
      def destroy_multiple_custom_categories
        event = Event.find_by(id: params[:event_id])
        unless event
          api_error(message: 'Event not found', status: :not_found)
          return
        end

        # unless can_manage_event?(event)
        #   api_error(message: 'You do not have permission to manage this event', status: :forbidden)
        #   return
        # end

        custom_category_ids = Array(params[:custom_category_ids]).map(&:to_s).reject(&:blank?)
        
        if custom_category_ids.empty?
          api_error(message: 'At least one custom_category_id is required', status: :bad_request)
          return
        end

        deleted = []
        not_found = []

        custom_category_ids.each do |cc_id|
          custom_category = event.event_custom_categories.find_by(id: cc_id)
          if custom_category&.destroy
            deleted << cc_id
          else
            not_found << cc_id
          end
        end

        api_success(
          data: {
            event_id: event.id,
            deleted_ids: deleted,
            not_found_ids: not_found,
            total_custom_categories: event.reload.event_custom_categories.count
          },
          message: "#{deleted.length} custom categor#{deleted.length == 1 ? 'y' : 'ies'} deleted#{not_found.any? ? ", #{not_found.length} not found" : ''}",
          status: :ok
        )
      end

      # =====================================================
      # BOOST EVENT ENDPOINTS
      # =====================================================

      # GET /api/v1/events/:id/boosts
      # List all boosts for an event
      def list_boosts
        return if performed?
        
        # unless can_manage_event?(@event)
        #   api_error(message: 'You do not have permission to view boosts for this event', status: :forbidden)
        #   return
        # end

        boosts = @event.event_boosts.order(created_at: :desc)
        
        limit = [params[:limit]&.to_i || 20, 100].min
        offset = params[:offset]&.to_i || 0
        total_count = boosts.count
        boosts = boosts.limit(limit).offset(offset)

        api_success(
          data: {
            event_id: @event.id,
            boosts: boosts.map { |boost| boost_response(boost) },
            active_boost: @event.active_boost ? boost_response(@event.active_boost) : nil,
            is_boosted: @event.is_boosted?,
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

      # POST /api/v1/events/:id/boost
      # Create a new boost for an event
      def create_boost
        return if performed?
        
        # unless can_manage_event?(@event)
        #   api_error(message: 'You do not have permission to boost this event', status: :forbidden)
        #   return
        # end

        # Check if there's already an active or pending boost
        if @event.event_boosts.where(status: ['active', 'pending_review']).exists?
          api_error(message: 'Event already has an active or pending boost', status: :bad_request)
          return
        end

        boost = @event.event_boosts.build(boost_params)
        boost.created_by = current_user
        boost.status = 'draft'

        if boost.save
          api_success(
            data: { 
              boost: boost_detail_response(boost),
              event: event_response(@event, request: request)
            },
            message: 'Boost created successfully',
            status: :created
          )
        else
          api_validation_error(errors: boost.errors.full_messages)
        end
      rescue => e
        Rails.logger.error "Create Boost Error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        api_error(message: 'Failed to create boost', status: :internal_server_error)
      end

      # GET /api/v1/events/:id/boost/:boost_id
      # Show boost details
      def show_boost
        return if performed?
        
        boost = @event.event_boosts.find_by(id: params[:boost_id])
        unless boost
          api_error(message: 'Boost not found', status: :not_found)
          return
        end

        # unless can_manage_event?(@event) || current_user.role_admin?
        #   api_error(message: 'You do not have permission to view this boost', status: :forbidden)
        #   return
        # end

        api_success(
          data: { 
            boost: boost_detail_response(boost),
            event: event_response(@event, request: request)
          },
          status: :ok
        )
      end

      # PATCH /api/v1/events/:id/boost/:boost_id
      # Update boost settings
      def update_boost
        return if performed?
        
        boost = @event.event_boosts.find_by(id: params[:boost_id])
        unless boost
          api_error(message: 'Boost not found', status: :not_found)
          return
        end

        # unless can_manage_event?(@event)
        #   api_error(message: 'You do not have permission to update this boost', status: :forbidden)
        #   return
        # end

        unless boost.can_edit?
          api_error(message: 'Boost cannot be edited in its current status', status: :bad_request)
          return
        end

        if boost.update(boost_params)
          api_success(
            data: { boost: boost_detail_response(boost) },
            message: 'Boost updated successfully',
            status: :ok
          )
        else
          api_validation_error(errors: boost.errors.full_messages)
        end
      rescue => e
        Rails.logger.error "Update Boost Error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        api_error(message: 'Failed to update boost', status: :internal_server_error)
      end

      # POST /api/v1/events/:id/boost/:boost_id/submit
      # Submit boost for review
      def submit_boost_for_review
        return if performed?
        
        boost = @event.event_boosts.find_by(id: params[:boost_id])
        unless boost
          api_error(message: 'Boost not found', status: :not_found)
          return
        end

        # unless can_manage_event?(@event)
        #   api_error(message: 'You do not have permission to submit this boost', status: :forbidden)
        #   return
        # end

        if boost.submit_for_review!
          api_success(
            data: { boost: boost_detail_response(boost) },
            message: 'Boost submitted for review',
            status: :ok
          )
        else
          api_error(message: 'Boost can only be submitted from draft status', status: :bad_request)
        end
      end

      # POST /api/v1/events/:id/boost/:boost_id/pause
      # Pause an active boost
      def pause_boost
        return if performed?
        
        boost = @event.event_boosts.find_by(id: params[:boost_id])
        unless boost
          api_error(message: 'Boost not found', status: :not_found)
          return
        end

        # unless can_manage_event?(@event)
        #   api_error(message: 'You do not have permission to pause this boost', status: :forbidden)
        #   return
        # end

        if boost.pause!
          api_success(
            data: { boost: boost_detail_response(boost) },
            message: 'Boost paused successfully',
            status: :ok
          )
        else
          api_error(message: 'Only active boosts can be paused', status: :bad_request)
        end
      end

      # POST /api/v1/events/:id/boost/:boost_id/resume
      # Resume a paused boost
      def resume_boost
        return if performed?
        
        boost = @event.event_boosts.find_by(id: params[:boost_id])
        unless boost
          api_error(message: 'Boost not found', status: :not_found)
          return
        end

        # unless can_manage_event?(@event)
        #   api_error(message: 'You do not have permission to resume this boost', status: :forbidden)
        #   return
        # end

        if boost.resume!
          api_success(
            data: { boost: boost_detail_response(boost) },
            message: 'Boost resumed successfully',
            status: :ok
          )
        else
          api_error(message: 'Only paused boosts can be resumed', status: :bad_request)
        end
      end

      # DELETE /api/v1/events/:id/boost/:boost_id
      # Cancel a boost
      def cancel_boost
        return if performed?
        
        boost = @event.event_boosts.find_by(id: params[:boost_id])
        unless boost
          api_error(message: 'Boost not found', status: :not_found)
          return
        end

        # unless can_manage_event?(@event)
        #   api_error(message: 'You do not have permission to cancel this boost', status: :forbidden)
        #   return
        # end

        unless boost.can_cancel?
          api_error(message: 'Boost cannot be cancelled in its current status', status: :bad_request)
          return
        end

        if boost.cancel!
          api_success(
            data: { boost: boost_detail_response(boost) },
            message: 'Boost cancelled successfully',
            status: :ok
          )
        else
          api_error(message: 'Failed to cancel boost', status: :unprocessable_entity)
        end
      end

      # GET /api/v1/events/boost/performance_goals
      # List available performance goal options
      def boost_performance_goals
        goals = EventBoost::PERFORMANCE_GOALS.map do |goal|
          {
            value: goal,
            label: goal.humanize.titleize,
            description: boost_goal_description(goal)
          }
        end

        api_success(
          data: { performance_goals: goals },
          status: :ok
        )
      end

      # GET /api/v1/events/boost/targeting_options
      # List available targeting options
      def boost_targeting_options
        genders = EventBoost::GENDERS.map do |gender|
          {
            value: gender,
            label: gender == 'all' ? 'All Genders' : gender.capitalize
          }
        end

        api_success(
          data: {
            genders: genders,
            age_range: {
              min: 13,
              max: 120,
              default_min: 18,
              default_max: 65
            },
            geo_fence: {
              min_radius_km: 1,
              max_radius_km: 500,
              default_radius_km: 10
            }
          },
          status: :ok
        )
      end
      
      private

      def authorize_event_share!
        return if @event.visibility_public?

        unless current_user
          api_error(message: 'Unauthorized', status: :unauthorized)
          return
        end

        return if @event.can_share_invite?(current_user)

        api_error(message: 'You cannot share this invite', status: :forbidden)
      end

      def invite_payload(event, base_url:)
        token = event.invite_token
        return {} if token.blank?

        q = { token: token }.to_query
        {
          invite_token: token,
          invite_sharing: event.invite_sharing,
          invite_api_url: "#{base_url}/api/v1/events/by_invite?#{q}",
          invite_deep_link: "vibes://events/#{event.id}?invite=#{token}"
        }
      end

      # Returns Event::CATEGORIES sorted by "most used" for current user.
      # Venue manager / admin: by event count at their venues (event.category).
      # Normal user / artist: by their booking count per event category.
      def event_categories_sorted_by_usage
        counts = if current_user.role_venue_manager? || current_user.role_admin?
          # Count events created at venues owned by current user, grouped by category
          Event.joins(:venue)
               .where(venues: { owner_id: current_user.id })
               .where.not(category: [nil, ''])
               .group(:category)
               .count
        else
          # Count current user's bookings (confirmed/created/checked_in) grouped by event category
          Booking.where(user_id: current_user.id)
                 .where(status: %w[created confirmed checked_in])
                 .joins(:event)
                 .where.not(events: { category: [nil, ''] })
                 .group('events.category')
                 .count
        end

        # Sort Event::CATEGORIES by count desc; categories with no usage keep default order at the end
        ordered = Event::CATEGORIES.sort_by { |cat| -(counts[cat] || 0) }
        ordered
      end

      def set_event
        event_id = params[:id] || params[:event_id]
        @event = Event.includes(EVENT_TICKET_TYPES_INCLUDE, :venue, event_artists: :artist, venue: :owner, photos_attachments: :blob).find_by(id: event_id)
        unless @event
          api_error(message: 'Event not found', status: :not_found)
          return
        end
      end
      
      def set_venue
        @venue = Venue.find_by(id: params[:venue_id])
        unless @venue
          api_error(message: 'Venue not found', status: :not_found)
          return
        end
      end
      
      def last_address_suggestion_payload(record)
        case record
        when Event
          {
            address1: record.address1,
            address2: record.address2,
            city: record.city,
            region: record.region,
            postal_code: record.postal_code,
            country: record.country,
            latitude: record.latitude&.to_f,
            longitude: record.longitude&.to_f,
            full_address: record.full_address
          }
        when Venue
          {
            address1: record.address1,
            address2: record.address2,
            city: record.city,
            region: record.region,
            postal_code: record.postal_code,
            country: record.country,
            latitude: record.latitude&.to_f,
            longitude: record.longitude&.to_f,
            full_address: record.full_address
          }
        else
          {}
        end
      end
      
      def boost_params
        params.require(:boost).permit(
          :performance_goal,
          :starts_at,
          :ends_at,
          :timezone,
          :target_age_min,
          :target_age_max,
          :target_gender,
          :geo_fence_address,
          :geo_fence_city,
          :geo_fence_region,
          :geo_fence_country,
          :geo_fence_latitude,
          :geo_fence_longitude,
          :geo_fence_radius_km,
          :daily_budget,
          :total_budget,
          :currency,
          :notes
        )
      end

      def boost_response(boost)
        {
          id: boost.id,
          event_id: boost.event_id,
          performance_goal: boost.performance_goal,
          status: boost.status,
          starts_at: boost.starts_at,
          ends_at: boost.ends_at,
          timezone: boost.timezone,
          target_audience: boost.target_audience,
          is_running: boost.is_running?,
          is_scheduled: boost.is_scheduled?,
          created_at: boost.created_at,
          updated_at: boost.updated_at
        }
      end

      def boost_detail_response(boost)
        boost_response(boost).merge(
          created_by: {
            id: boost.created_by.id,
            name: boost.created_by.name,
            username: boost.created_by.username
          },
          schedule: {
            starts_at: boost.starts_at,
            ends_at: boost.ends_at,
            timezone: boost.timezone,
            duration_days: boost.duration_days,
            days_remaining: boost.days_remaining
          },
          targeting: {
            age_range: {
              min: boost.target_age_min,
              max: boost.target_age_max
            },
            gender: boost.target_gender,
            geo_fence: boost.geo_fence_location
          },
          budget: {
            daily_budget: boost.daily_budget,
            total_budget: boost.total_budget,
            currency: boost.currency,
            amount_spent: boost.amount_spent,
            budget_remaining: boost.budget_remaining,
            budget_spent_percentage: boost.budget_spent_percentage,
            is_budget_exhausted: boost.is_budget_exhausted?
          },
          performance: boost.performance_metrics,
          status_details: {
            status: boost.status,
            approved_at: boost.approved_at,
            paused_at: boost.paused_at,
            completed_at: boost.completed_at,
            rejected_at: boost.rejected_at,
            cancelled_at: boost.cancelled_at,
            rejection_reason: boost.rejection_reason,
            can_edit: boost.can_edit?,
            can_cancel: boost.can_cancel?
          },
          notes: boost.notes,
          metadata: boost.metadata
        )
      end

      def boost_goal_description(goal)
        case goal
        when 'page_views'
          'Maximize the number of users who view your event page'
        when 'link_clicks'
          'Maximize the number of clicks on your event links'
        when 'daily_reach'
          'Maximize daily reach among unique users in your target audience'
        else
          ''
        end
      end

      def custom_category_params
        params.require(:custom_category).permit(:name, :description)
      end

      def custom_category_response(custom_category)
        {
          id: custom_category.id,
          event_id: custom_category.event_id,
          name: custom_category.name,
          description: custom_category.description,
          created_at: custom_category.created_at,
          updated_at: custom_category.updated_at
        }
      end
      
      # `event` is optional so PATCH can send only ticket_types / data.ticket_types (same as PUT .../ticket_types).
      # Create with no `event` yields empty permitted attrs (validations still require title, etc.).
      def event_params
        src = params[:event]
        src = if src.nil?
                ActionController::Parameters.new
              elsif src.is_a?(ActionController::Parameters)
                src
              else
                ActionController::Parameters.new(src)
              end
        permit_event_attributes(src)
      end

      def permit_event_attributes(src)
        src.permit(
          :title,
          :description,
          :starts_at,
          :ends_at,
          :category,
          :timezone,
          :price,
          :currency,
          :is_free,
          :adult_price,
          :child_price,
          :infant_price,
          :pet_price,
          :visibility,
          :dress_code,
          :age_restriction,
          :smoking,
          :cancellation_policy_enabled,
          :cancellation_deadline_hours,
          :cancellation_fee_percentage,
          :booking_opens_after_event_start,
          # Address fields (optional - override venue address)
          :address1,
          :address2,
          :city,
          :region,
          :postal_code,
          :country,
          :latitude,
          :longitude,
          # Poster/cover image URL
          :poster_url,
          # ID requirement fields
          :id_required,
          :id_requirement_description,
          :restrictions,
          :access_instructions,
          :pre_booking_price,
          :pre_booking_deadline,
          :collaborator_type,
          :collaborator_id,
          # Attendance: rsvp (Live+Map) | tickets (close 24h before)
          :attendance_mode,
          # Business-side fee: exclusive (2%) | non_exclusive (5%)
          :pr_commission_type,
          :invite_sharing,
          photo_urls: []
        )
      end

      # Accept tags on create/update without polluting Event attributes.
      # Supports:
      # - event.tag_ids: [uuid, ...]
      # - tag_ids (root): [uuid, ...]
      # - event.tag_slugs: ["trending", ...]
      # - tag_slugs (root): ["trending", ...]
      def apply_event_tags!(event)
        ids = coerce_string_array(params.dig(:event, :tag_ids) || params.dig(:event, 'tag_ids') || params[:tag_ids] || params['tag_ids'])
        slugs = coerce_string_array(params.dig(:event, :tag_slugs) || params.dig(:event, 'tag_slugs') || params[:tag_slugs] || params['tag_slugs'])

        return if ids.empty? && slugs.empty?

        tags = []
        if ids.any?
          tags = EventTag.where(id: ids)
          missing = ids - tags.pluck(:id).map(&:to_s)
          unless missing.empty?
            raise ArgumentError, "Unknown tag_ids: #{missing.join(', ')}"
          end
        elsif slugs.any?
          tags = resolve_event_tags_by_slugs(slugs, event_country: event.event_country)
          missing = slugs - tags.map(&:slug)
          unless missing.empty?
            raise ArgumentError, "Unknown tag_slugs: #{missing.join(', ')}"
          end
        end

        event.event_tags = tags
      end

      def resolve_event_tags_by_slugs(slugs, event_country:)
        wanted = slugs.map(&:to_s).map(&:strip).reject(&:blank?).uniq
        return [] if wanted.empty?

        rows = EventTag.where(slug: wanted)
        rows = if event_country.present?
                 rows.where(country: [event_country, nil])
               else
                 rows.where(country: nil)
               end

        # Prefer country-specific tag over global when both exist.
        grouped = rows.to_a.group_by(&:slug)
        wanted.filter_map do |slug|
          candidates = grouped[slug] || []
          candidates.find { |t| t.country.present? } || candidates.first
        end
      end

      def coerce_string_array(val)
        case val
        when nil
          []
        when String
          s = val.strip
          return [] if s.blank?
          if s.start_with?('[') && s.end_with?(']')
            begin
              parsed = JSON.parse(s)
              Array(parsed).map(&:to_s)
            rescue JSON::ParserError
              [s]
            end
          else
            [s]
          end
        when Array
          val.flatten.compact.map(&:to_s).map(&:strip).reject(&:blank?)
        else
          Array(val).compact.map(&:to_s).map(&:strip).reject(&:blank?)
        end.uniq
      end

      # Optional ticket tiers on POST/PATCH: same payload as PUT .../ticket_types, e.g. root
      #   { "event": { ... }, "ticket_types": [ { "name", "price", "quantity_total", "display_order" } ] }
      def should_apply_ticket_types?
        ev = params[:event]
        return true if ev.respond_to?(:key?) && (ev.key?(:ticket_types) || ev.key?('ticket_types'))
        return true if params.key?(:ticket_types) || params.key?('ticket_types')
        data = params[:data]
        return true if data.respond_to?(:key?) && (data.key?(:ticket_types) || data.key?('ticket_types'))
        false
      end

      # Prefer root ticket_types when present (multipart clients often send JSON there); otherwise
      # event.ticket_types, then data.ticket_types.
      def ticket_types_array_from_params
        ev = params[:event]
        from_event = (ev.respond_to?(:key?) && (ev.key?(:ticket_types) || ev.key?('ticket_types'))) &&
                     (params.dig(:event, :ticket_types) || params.dig(:event, 'ticket_types'))
        from_root = params[:ticket_types] || params['ticket_types']
        from_data = params.dig(:data, :ticket_types) || params.dig(:data, 'ticket_types')

        raw = if present_ticket_types_param?(from_root)
                from_root
              elsif present_ticket_types_param?(from_event)
                from_event
              elsif present_ticket_types_param?(from_data)
                from_data
              else
                from_root || from_event || from_data
              end
        coerce_ticket_types_to_array(raw)
      end

      def present_ticket_types_param?(val)
        return false if val.nil?
        return false if val.is_a?(String) && val.strip.blank?
        return false if val.is_a?(Array) && val.empty?

        true
      end

      # Multipart clients send ticket_types as a JSON string, ["[{...}]"], or an array of JSON object strings.
      def coerce_ticket_types_to_array(raw)
        return nil if raw.nil?

        if raw.is_a?(String)
          stripped = raw.strip
          return [] if stripped.blank?

          parsed = JSON.parse(stripped)
          return wrap_ticket_types_json(parsed)
        end

        if raw.is_a?(Array)
          if raw.one? && raw.first.is_a?(String)
            inner = coerce_ticket_types_to_array(raw.first)
            return inner if inner.is_a?(Array)
          end
          if raw.any? { |e| e.is_a?(String) }
            return raw.flat_map do |e|
              next [e] unless e.is_a?(String)

              inner = coerce_ticket_types_to_array(e)
              inner.is_a?(Array) ? inner : [inner].compact
            end
          end
          return raw
        end

        raw
      rescue JSON::ParserError
        raw
      end

      def wrap_ticket_types_json(parsed)
        case parsed
        when Array then parsed
        when Hash then [parsed]
        else nil
        end
      end

      def normalize_age_pricing_params!
        event_params = params[:event]
        return unless event_params.is_a?(ActionController::Parameters) || event_params.is_a?(Hash)

        age_price = event_params[:age_price] || event_params['age_price']
        return unless age_price.is_a?(ActionController::Parameters) || age_price.is_a?(Hash)

        event_params['adult_price'] = age_price[:adult_price] || age_price['adult_price']
        event_params['child_price'] = age_price[:child_price] || age_price['child_price']
        event_params['infant_price'] = age_price[:infant_price] || age_price['infant_price']
        event_params['pet_price'] = age_price[:pet_price] || age_price['pet_price']
      end
      
      # Normalizes collaborator_type from API-friendly values to polymorphic class names
      # and clears invalid collaborator data to avoid constantize errors.
      #
      # Accepted inputs:
      # - "venue"  -> collaborator_type = "Venue"
      # - "brand"  -> collaborator_type = "User"
      #
      # Any other non-blank value will result in collaborator_type and collaborator_id
      # being cleared so we don't attempt to constantize an invalid class name
      # (e.g., "The Grand Club").
      def normalize_collaborator_params!
        event_params = params[:event]
        return unless event_params.is_a?(ActionController::Parameters) || event_params.is_a?(Hash)

        raw_type = event_params[:collaborator_type] || event_params['collaborator_type']
        return if raw_type.blank?

        normalized =
          case raw_type.to_s.downcase.strip
          when 'venue'
            'Venue'
          when 'brand'
            'User'
          else
            nil
          end

        if normalized
          event_params['collaborator_type'] = normalized
        else
          # Invalid collaborator_type; clear both fields to avoid runtime errors
          event_params['collaborator_type'] = nil
          event_params['collaborator_id'] = nil
        end
      end
      
      # Add artists from params[:artists] during event creation.
      # Each item: { artist_id: "uuid" } OR { artist_name: "Free-form name" }
      def add_inline_artists(event)
        artists_data = params[:artists] || params.dig(:event, :artists)
        return if artists_data.blank?

        permitted = params.permit(artists: [:artist_id, :artist_name, :scheduled_start_at, :scheduled_end_at, :timezone, :description, :status])
        artists_data = permitted[:artists] || artists_data

        max_order = event.event_artists.maximum(:display_order) || -1
        artists_data.each_with_index do |item, idx|
          item = item.to_h.with_indifferent_access
          next if item[:artist_id].blank? && item[:artist_name].blank?

          artist = nil
          if item[:artist_id].present?
            artist = User.find_by(id: item[:artist_id])
            next unless artist&.role_artist?
            next if event.event_artists.exists?(artist_id: artist.id)
          end

          event.event_artists.create!(
            artist: artist,
            artist_name: item[:artist_name],
            scheduled_start_at: item[:scheduled_start_at].present? ? Time.parse(item[:scheduled_start_at].to_s) : event.starts_at,
            scheduled_end_at: item[:scheduled_end_at].present? ? Time.parse(item[:scheduled_end_at].to_s) : event.ends_at,
            timezone: item[:timezone].presence || event.timezone,
            display_order: max_order + 1 + idx,
            description: item[:description],
            status: 'confirmed'
          )
        end
      rescue ArgumentError, ActiveRecord::RecordInvalid => e
        Rails.logger.warn "add_inline_artists: #{e.message}"
      end

      def can_manage_event?(event)
        return true if current_user.role_admin?
        return true if event.creator_id == current_user.id
        if event.venue
          return true if event.venue.owner_id == current_user.id
          return true if event.venue.venue_staff.exists?(user_id: current_user.id, role: 'manager')
          # PR users manage pricing/details via booking APIs (PATCH /bookings/:id), not PATCH /events/:id
        end
        if event.collaborator_type == 'brand' && event.collaborator_id == current_user.id
          return true
        end
        false
      end

      def authorize_manage_event!
        return if performed?
        return if can_manage_event?(@event)

        api_error(message: 'You do not have permission to manage this event', status: :forbidden)
      end

      # One tier object: same fields as booking `ticket_type` and GET .../ticket_types.
      def event_ticket_type_payload(t, event)
        {
          id: t.id.to_s,
          name: t.name,
          price: t.price.to_f,
          currency: t.currency.presence || event&.currency,
          quantity_total: t.quantity_total,
          quantity_sold: t.quantity_sold,
          quantity_available: t.quantity_available,
          display_order: t.display_order
        }
      end
      
      def event_response(event, request: nil)
        # Calculate average rating (from ratings or vibe_checks)
        average_rating = event.ratings.approved.average(:rating)&.round(2) || 
                        event.vibe_check_rating || 
                        nil
        ratings_count = event.ratings.approved.count + event.vibe_checks_count
        
        # Get base URL for photo URLs
        base_url = request&.base_url || ENV['API_BASE_URL'] || 'https://vibesapp.digital4design.com'
        
        collaborator_payload = nil
        if event.collaborator
          collaborator_payload = {
            type: event.collaborator_type,
            id: event.collaborator_id,
            name: event.collaborator.respond_to?(:name) ? event.collaborator.name : event.collaborator.try(:username)
          }
        end

        venue_payload =
          if event.venue
            {
              id: event.venue.id,
              name: event.venue.name,
              rsvp_enabled: event.venue.rsvp_enabled != false,
              image_url: event.venue.image_url(host: base_url)
            }
          else
            nil
          end

        posted_by_payload =
          if event.venue&.owner
            {
              id: event.venue.owner.id,
              name: event.venue.owner.name,
              username: event.venue.owner.username
            }
          else
            nil
          end

        creator_payload =
          if event.creator
            {
              id: event.creator.id,
              name: event.creator.name,
              username: event.creator.username,
              role: event.creator.role
            }
          else
            nil
          end

        {
          id: event.id,
          name: event.title,
          title: event.title,
          description: event.description,
          category: event.category, # Legacy single category
          categories: event.all_categories, # Multiple categories (like artists)
          tags: event.event_tags.ordered.map { |t| { id: t.id, slug: t.slug, name: t.name, country: t.country, category_slug: t.category_slug } },
          collaborator: collaborator_payload,
          # Address information (uses venue address when event doesn't override)
          address: event.full_address,
          address_details: build_event_address_details(event),
          start_time: event.starts_at,
          end_time: event.ends_at,
          status: event.status,
          published: event.status == 'published',
          price: event.display_price,
          currency: event.currency,
          is_free: event.is_free,
          age_pricing_enabled: event.age_pricing_enabled?,
          adult_price: event.adult_price,
          child_price: event.child_price,
          infant_price: event.infant_price,
          pet_price: event.pet_price,
          visibility: event.visibility,
          # Poster/cover image
          poster_url: event.poster_image_url(host: base_url),
          has_poster: event.has_poster?,
          photos: event.photo_urls_array(host: base_url),
          photos_count: event.photos_count,
          has_photos: event.has_photos?,
          venue: venue_payload,
          posted_by: posted_by_payload,
          created_by: creator_payload,
          likes_count: event.likes_count,
          user_liked: event.user_liked?(current_user),
          interests_count: event.interests_count,
          user_interested: event.user_interested?(current_user),
          rsvps_count: event.rsvps_count,
          user_has_rsvp: event.user_has_rsvp?(current_user),
          user_rsvp_status: event.user_rsvp_status(current_user),
          user_rsvp_yes_count: event.rsvp_yes_count,
          user_rsvp_no_count: event.rsvp_no_count,
          user_rsvp_maybe_count: event.rsvp_maybe_count,
          user_rsvp_count: event.rsvp_count,
          user_booked: event.user_booked?(current_user),
          user_reports_count: event.reports_count,
          user_reported: event.user_reported?(current_user),
          rating: average_rating,
          ratings_count: ratings_count,
          reviews_count: event.reviews_count,
          average_rating_out_of_10: average_rating ? (average_rating * 2.0).round(1) : nil,
          age_restriction: event.age_restriction,
          smoking: event.smoking,
          custom_categories: event.event_custom_categories.ordered.map { |cc| custom_category_response(cc) },
          is_boosted: event.is_boosted?,
          # Attendance: rsvp (Live+Map) | tickets (close 24h before)
          attendance_mode: event.attendance_mode || 'rsvp',
          tickets_closed: event.tickets_closed?,
          ticket_sales_open: event.ticket_sales_open?,
          rsvp_allowed: event.rsvp_changes_allowed?,
          venue_rsvp_enabled: event.venue_rsvp_enabled?,
          ticket_types: event.event_ticket_types.sort_by { |t| [t.display_order, t.id] }.map { |t|
            detail = event_ticket_type_payload(t, event)
            # Nested `ticket_type` matches booking payloads; flat keys remain for older clients.
            detail.merge(ticket_type: detail.deep_dup)
          },
          # Business-side fee: exclusive (2%) | non_exclusive (5%)
          pr_commission_type: event.pr_commission_type,
          pr_commission_percentage: event.pr_commission_percentage,
          created_at: event.created_at,
          updated_at: event.updated_at
        }
      end
      
      def event_detail_response(event, request: nil, include_attendees: nil)
        # Calculate joined count (bookings + interests)
        joined_count = event.bookings.confirmed.count + event.event_interests.attending.sum { |i| i.total_attendees || 1 }
        
        base = event_response(event, request: request).merge(
          start_date_time: event.starts_at,
          end_date_time: event.ends_at,
          rsvp_minimum_time: event.cancellation_deadline_hours, # Hours before event for RSVP/cancellation deadline
          artists: event.event_artists.includes(:artist).ordered.map { |ea|
            {
              id: ea.id,
              artist_id: ea.artist_id,
              artist_name: ea.artist_name,
              name: ea.display_name,
              username: ea.artist&.username,
              time: {
                scheduled_start_at: ea.scheduled_start_at,
                scheduled_end_at: ea.scheduled_end_at,
                timezone: ea.timezone
              },
              status: ea.status
            }
          },
          likes_count: event.likes_count,
          user_liked: event.user_liked?(current_user),
          interests_count: event.interests_count,
          user_interested: event.user_interested?(current_user),
          rsvps_count: event.rsvps_count,
          user_has_rsvp: event.user_has_rsvp?(current_user),
          user_rsvp_status: event.user_rsvp_status(current_user),
          user_rsvp_yes_count: event.rsvp_yes_count,
          user_rsvp_no_count: event.rsvp_no_count,
          user_rsvp_maybe_count: event.rsvp_maybe_count,
          user_rsvp_count: event.rsvp_count,
          user_booked: event.user_booked?(current_user),
          user_reports_count: event.reports_count,
          user_reported: event.user_reported?(current_user),
          joined_count: joined_count,
          bookings_count: event.bookings.confirmed.count,
          dress_code: event.dress_code,
          age_restriction: event.age_restriction,
          smoking: event.smoking,
          # Custom categories
          custom_categories: event.event_custom_categories.ordered.map { |cc| custom_category_response(cc) },
          # ID requirements
          id_required: event.id_required,
          id_requirement_description: event.id_requirement_description,
          restrictions: event.restrictions,
          access_instructions: event.access_instructions,
          # Pre-booking
          pre_booking_price: event.pre_booking_price,
          pre_booking_deadline: event.pre_booking_deadline,
          # Cancellation policy
          cancellation_policy_info: event.cancellation_policy_info,
          cancellation_policy_enabled: event.cancellation_policy_enabled,
          cancellation_deadline_hours: event.cancellation_deadline_hours,
          cancellation_fee_percentage: event.cancellation_fee_percentage,
          # Available categories (for reference)
          available_categories: Event::CATEGORIES,
          # Boost information
          is_boosted: event.is_boosted?,
          active_boost: event.active_boost ? boost_response(event.active_boost) : nil,
          boosts_count: event.boosts_count
        )
        
        if include_attendees.to_s == 'true'
          base[:going] = going_payload(event)
          if current_user && !current_user.role_venue_manager? && !current_user.role_brand?
            booking = event.bookings.find_by(user: current_user)
            base[:my_booking] = booking ? my_booking_payload(booking) : nil
          end
        end

        if event.visibility_private? || event.visibility_unlisted?
          base[:invite] = {
            sharing: event.invite_sharing,
            can_share: current_user.present? && event.can_share_invite?(current_user)
          }
        end
        
        base
      end
      
      def going_payload(event)
        user_ids = event.bookings
                       .where(status: %w[created confirmed checked_in])
                       .order(created_at: :desc)
                       .pluck(:user_id)
                       .uniq
        count = user_ids.size
        limit = [(params[:attendees_limit] || 50).to_i, 50].min
        limited_ids = user_ids.first(limit)
        users_by_id = User.where(id: limited_ids).includes(profile_picture_attachment: :blob).index_by(&:id)
        users_ordered = limited_ids.filter_map { |id| users_by_id[id] }
        profile_images = users_ordered.map do |u|
          if u.profile_picture.attached?
            url_for(u.profile_picture)
          elsif u.respond_to?(:profile_picture_url) && u.profile_picture_url.present?
            u.profile_picture_url
          else
            default_avatar_url
          end
        end
        {
          count: count,
          profile_images: profile_images
        }
      end

      def my_booking_payload(booking)
        preorders = booking.food_bar_orders
        {
          id: booking.id,
          status: booking.status,
          table_number: booking.table_number,
          price: booking.price.to_f,
          total_price: booking.total_price_with_preorders,
          payment_status: booking.payment_status,
          paid_amount: booking.paid_amount.to_f,
          remaining_amount: booking.remaining_amount.to_f,
          expiry_at: booking.expiry_at&.iso8601,
          attendees: {
            adults_count: booking.adults_count,
            children_count: booking.children_count,
            infants_count: booking.infants_count,
            pets_count: booking.pets_count,
            total_count: booking.total_attendees_count
          },
          preorder: {
            has_preorder: preorders.any?,
            items_count: preorders.sum { |o| o.food_bar_order_items.count },
            total_amount: preorders.sum(&:total_amount).to_f
          },
          created_at: booking.created_at.iso8601
        }
      end
      
      def user_basic_response(user)
        {
          id: user.id,
          username: user.username,
          name: user.name,
          role: user.role,
          avatar_url: user.avatar_url
        }
      end
      
      # Build address details - returns venue address when event doesn't override
      def build_event_address_details(event)
        uses_venue_address = !event.location_overridden?
        
        if uses_venue_address
          # Return venue's address
          venue = event.venue
          {
            address1: venue.address1,
            address2: venue.address2,
            city: venue.city,
            region: venue.region,
            postal_code: venue.postal_code,
            country: venue.country,
            latitude: venue.latitude,
            longitude: venue.longitude,
            uses_venue_address: true
          }
        else
          # Return event's overridden address
          {
            address1: event.address1,
            address2: event.address2,
            city: event.city,
            region: event.region,
            postal_code: event.postal_code,
            country: event.country,
            latitude: event.latitude,
            longitude: event.longitude,
            uses_venue_address: false
          }
        end
      end

      def parse_datetime(datetime_string)
        return nil if datetime_string.blank?
        
        # Try parsing ISO 8601 format
        begin
          Time.parse(datetime_string)
        rescue ArgumentError
          # Try parsing as timestamp (integer seconds)
          begin
            Time.at(datetime_string.to_i)
          rescue
            nil
          end
        end
      end

      # GET /api/v1/events — optional ?published=true|false (only when `status` is not passed)
      def published_filter_param_provided?
        !params[:published].nil? && params[:published].to_s != ''
      end

      def published_filter_status
        ActiveModel::Type::Boolean.new.cast(params[:published]) ? 'published' : 'draft'
      end

      def build_filters_summary
        filters = {}
        
        # Distance filters
        if params[:lat].present? && params[:lng].present?
          filters[:location] = {
            latitude: params[:lat].to_f,
            longitude: params[:lng].to_f
          }
          if params[:min_distance].present? || params[:max_distance].present?
            filters[:distance] = {}
            filters[:distance][:min_km] = params[:min_distance].to_f if params[:min_distance].present?
            filters[:distance][:max_km] = params[:max_distance].to_f if params[:max_distance].present?
          end
        end
        
        # Date/time filters
        if params[:start_date].present?
          filters[:start_date] = params[:start_date]
        end
        if params[:end_date].present?
          filters[:end_date] = params[:end_date]
        end
        if params[:date_from].present? && params[:date_to].present?
          filters[:date_range] = {
            from: params[:date_from],
            to: params[:date_to]
          }
        end
        if params[:time_from].present? || params[:time_to].present?
          filters[:time_range] = {}
          filters[:time_range][:from] = params[:time_from].to_i if params[:time_from].present?
          filters[:time_range][:to] = params[:time_to].to_i if params[:time_to].present?
        end
        if params[:time_filter].present?
          filters[:time_filter] = params[:time_filter]
        end
        
        # Category filters
        if params[:category].present?
          filters[:category] = Array(params[:category])
        end
        if params[:category_ids].present?
          filters[:category_ids] = Array(params[:category_ids])
        end
        if params[:category_slugs].present?
          filters[:category_slugs] = Array(params[:category_slugs])
        end
        
        # Venue filter
        if params[:venue_id].present?
          filters[:venue_id] = params[:venue_id]
        end
        
        # Status filter
        if params[:status].present?
          filters[:status] = Array(params[:status])
        elsif published_filter_param_provided?
          filters[:published] = ActiveModel::Type::Boolean.new.cast(params[:published])
        end

        # Search filter
        if params[:search].present?
          filters[:search] = params[:search]
        end
        
        filters
      end
    end
  end
end


