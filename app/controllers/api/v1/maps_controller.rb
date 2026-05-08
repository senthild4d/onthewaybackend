module Api
  module V1
    class MapsController < ApplicationController
      before_action :require_authentication!, except: [:index, :filter_options]

      # GET /api/v1/maps
      def index
        # Get venues, events, and stories with coordinates based on filters
        venues = params[:show_venues] != 'false' ? fetch_venues : []
        events = params[:show_events] != 'false' ? fetch_events : []
        stories = params[:show_stories] != 'false' ? fetch_stories : []

        # Convert to arrays to avoid count issues with DISTINCT ON queries
        venues_array = venues.is_a?(Array) ? venues : venues.to_a
        events_array = events.is_a?(Array) ? events : events.to_a
        stories_array = stories.is_a?(Array) ? stories : stories.to_a

        # Format for map display
        stories_responses = stories_array.filter_map { |story| map_story_response(story) }.first(50)
        all_items_for_bounds = venues_array + events_array + stories_array

        map_data = {
          venues: venues_array.map { |venue| map_venue_response(venue) },
          events: events_array.map { |event| map_event_response(event) }.compact,
          stories: stories_responses,
          bounds: calculate_bounds(all_items_for_bounds),
          metadata: {
            venues_count: venues_array.count,
            events_count: events_array.count,
            stories_count: stories_responses.count,
            total_markers: venues_array.count + events_array.count + stories_responses.count
          }
        }

        api_success(
          data: map_data,
          status: :ok
        )
      end

      # GET /api/v1/maps/filter_options
      def filter_options
        # Get available filter options for the map view
        options = {
          show_stories: { default: true, description: 'Include stories (venue/event-linked moments) in map' },
          categories: Event::CATEGORIES,
          time_filters: [
            { value: 'today', label: 'Today' },
            { value: 'this_week', label: 'This Week' },
            { value: 'this_month', label: 'This Month' },
            { value: 'upcoming', label: 'Upcoming' },
            { value: 'live', label: 'Live Now' }
          ],
          event_statuses: [
            { value: 'published', label: 'Published' },
            { value: 'live', label: 'Live' },
            { value: 'completed', label: 'Completed' }
          ],
          radius_options: [
            { value: 1, label: '1 km' },
            { value: 5, label: '5 km' },
            { value: 10, label: '10 km' },
            { value: 25, label: '25 km' },
            { value: 50, label: '50 km' },
            { value: 100, label: '100 km' }
          ],
          sort_options: [
            { value: 'distance', label: 'Distance' },
            { value: 'date', label: 'Date' },
            { value: 'popularity', label: 'Popularity' },
            { value: 'rating', label: 'Rating' }
          ]
        }

        api_success(
          data: options,
          status: :ok
        )
      end

      private

      def fetch_venues
        if current_user&.role_venue_manager?
          venues = current_user.venues.active
        else
          venues = Venue.active
        end

        venues = venues.includes(:owner, image_attachment: :blob)

        # Filter by bounding box if provided
        if bounding_box_provided?
          venues = venues.where(
            'latitude >= ? AND latitude <= ? AND longitude >= ? AND longitude <= ?',
            params[:south].to_f,
            params[:north].to_f,
            params[:west].to_f,
            params[:east].to_f
          )
        end

        # Filter by radius if center point provided
        if radius_search_provided?
          center_lat = params[:center_latitude].to_f
          center_lng = params[:center_longitude].to_f
          radius_km = params[:radius_km].to_f || 10.0

          # Haversine formula for distance calculation
          # Using approximate calculation (good for small distances)
          lat_range = radius_km / 111.0 # 1 degree latitude ≈ 111 km
          lng_range = radius_km / (111.0 * Math.cos(center_lat * Math::PI / 180.0))

          venues = venues.where(
            'latitude >= ? AND latitude <= ? AND longitude >= ? AND longitude <= ?',
            center_lat - lat_range,
            center_lat + lat_range,
            center_lng - lng_range,
            center_lng + lng_range
          )
        end

        # Filter by city
        venues = venues.by_city(params[:city]) if params[:city].present?

        # Filter by country
        venues = venues.by_country(params[:country]) if params[:country].present?

        # Search by name
        if params[:search].present?
          venues = venues.where("name ILIKE ?", "%#{params[:search]}%")
        end

        # Filter by minimum rating
        if params[:min_rating].present?
          venues = venues.joins(:approved_ratings)
                        .group('venues.id')
                        .having('AVG(ratings.rating) >= ?', params[:min_rating].to_f)
        end

        # Filter by minimum likes
        if params[:min_likes].present?
          venues = venues.joins(:likes)
                        .group('venues.id')
                        .having('COUNT(likes.id) >= ?', params[:min_likes].to_i)
        end

        # Sort venues
        case params[:sort_by]
        when 'rating'
          venues = venues.left_joins(:approved_ratings)
                        .group('venues.id')
                        .order('AVG(ratings.rating) DESC')
        when 'popularity'
          venues = venues.left_joins(:likes)
                        .group('venues.id')
                        .order('COUNT(likes.id) DESC')
        else
          venues = venues.order(created_at: :desc)
        end

        # Only return venues with coordinates
        venues = venues.where.not(latitude: nil, longitude: nil)

        # Limit results
        limit = [params[:limit]&.to_i || 100, 500].min
        # Convert to array for consistent handling
        venues_array = venues.limit(limit).to_a
        venues_array
      end

      def fetch_events
        events = Event.includes(venue: :owner, moments: :user, poster_attachment: :blob, photos_attachments: :blob)
                     .joins(:venue)
                     .where(venues: { status: 'active' })

        if current_user&.role_venue_manager?
          events = events.visible_to_user(current_user)
        end

        # Filter by status
        if params[:event_status].present?
          statuses = Array(params[:event_status])
          events = events.where(status: statuses)
        else
          # Default to upcoming and live events
          events = events.where(status: ['published', 'live'])
        end

        # Filter by visibility (only show public events to non-authenticated users)
        unless current_user && (current_user.role_venue_manager? || current_user.role_admin?)
          events = events.public_events
        end

        # Filter by time
        case params[:time_filter]
        when 'upcoming'
          events = events.upcoming
        when 'past'
          events = events.past
        when 'live'
          events = events.live
        when 'today'
          events = events.where('DATE(starts_at) = ?', Date.current)
        when 'this_week'
          events = events.where('starts_at >= ? AND starts_at <= ?', Date.current.beginning_of_week, Date.current.end_of_week)
        when 'this_month'
          events = events.where('starts_at >= ? AND starts_at <= ?', Date.current.beginning_of_month, Date.current.end_of_month)
        end

        # Filter by date range
        if params[:start_date].present?
          events = events.where('starts_at >= ?', params[:start_date])
        end
        if params[:end_date].present?
          events = events.where('starts_at <= ?', params[:end_date])
        end

        # Filter by category
        if params[:category].present?
          categories = Array(params[:category])
          unless categories.map(&:downcase).include?('all')
            events = events.where(category: categories)
          end
        end

        # Filter by age restriction
        if params[:max_age_restriction].present?
          events = events.where('age_restriction IS NULL OR age_restriction <= ?', params[:max_age_restriction].to_i)
        end

        # Filter by minimum rating (for venues)
        if params[:min_rating].present?
          # This would require joining with ratings, simplified for now
          # Can be enhanced with proper rating aggregation
        end

        # Filter by popularity (bookings/likes)
        # Note: These filters require grouping, so we'll apply them carefully
        needs_grouping = params[:min_bookings].present? || params[:min_likes].present? || params[:sort_by] == 'popularity'
        
        if needs_grouping
          events = events.left_joins(:bookings, :likes).group('events.id')
          
          if params[:min_bookings].present?
            events = events.having('COUNT(bookings.id) >= ?', params[:min_bookings].to_i)
          end
          
          if params[:min_likes].present?
            events = events.having('COUNT(likes.id) >= ?', params[:min_likes].to_i)
          end
        end

        # Sort options
        case params[:sort_by]
        when 'date'
          events = needs_grouping ? events.order('events.starts_at ' + (params[:sort_order] || 'asc')) : events.order(starts_at: params[:sort_order] || 'asc')
        when 'popularity'
          if needs_grouping
            events = events.order('COUNT(bookings.id) + COUNT(likes.id) DESC')
          else
            events = events.left_joins(:bookings, :likes)
                          .group('events.id')
                          .order('COUNT(bookings.id) + COUNT(likes.id) DESC')
          end
        when 'rating'
          # Would need rating aggregation - simplified for now
          events = needs_grouping ? events.order('events.created_at DESC') : events.order(created_at: :desc)
        else
          events = needs_grouping ? events.order('events.starts_at ASC') : events.order(starts_at: :asc)
        end

        # Filter by bounding box if provided
        if bounding_box_provided?
          # Events can have their own coordinates or use venue coordinates
          events = events.where(
            '(events.latitude >= ? AND events.latitude <= ? AND events.longitude >= ? AND events.longitude <= ?) OR ' \
            '(events.latitude IS NULL AND venues.latitude >= ? AND venues.latitude <= ? AND venues.longitude >= ? AND venues.longitude <= ?)',
            params[:south].to_f, params[:north].to_f, params[:west].to_f, params[:east].to_f,
            params[:south].to_f, params[:north].to_f, params[:west].to_f, params[:east].to_f
          )
        end

        # Filter by radius if center point provided
        if radius_search_provided?
          center_lat = params[:center_latitude].to_f
          center_lng = params[:center_longitude].to_f
          radius_km = params[:radius_km].to_f || 10.0

          lat_range = radius_km / 111.0
          lng_range = radius_km / (111.0 * Math.cos(center_lat * Math::PI / 180.0))

          events = events.where(
            '(events.latitude >= ? AND events.latitude <= ? AND events.longitude >= ? AND events.longitude <= ?) OR ' \
            '(events.latitude IS NULL AND venues.latitude >= ? AND venues.latitude <= ? AND venues.longitude >= ? AND venues.longitude <= ?)',
            center_lat - lat_range, center_lat + lat_range, center_lng - lng_range, center_lng + lng_range,
            center_lat - lat_range, center_lat + lat_range, center_lng - lng_range, center_lng + lng_range
          )
        end

        # Filter by city
        if params[:city].present?
          events = events.joins(:venue).where(venues: { city: params[:city] })
        end

        # Filter by country
        if params[:country].present?
          events = events.joins(:venue).where(venues: { country: params[:country] })
        end

        # Search by title
        if params[:search].present?
          events = events.where("events.title ILIKE ?", "%#{params[:search]}%")
        end

        # Only return events with coordinates (either event or venue)
        events = events.where(
          '(events.latitude IS NOT NULL AND events.longitude IS NOT NULL) OR ' \
          '(venues.latitude IS NOT NULL AND venues.longitude IS NOT NULL)'
        )

        # Ensure distinct results if not already grouped
        # Use distinct on ID to avoid JSON column issues with DISTINCT
        unless params[:min_bookings].present? || params[:min_likes].present? || params[:sort_by] == 'popularity'
          # Use DISTINCT ON (events.id) to avoid JSON column comparison issues
          # DISTINCT ON requires ORDER BY to start with events.id
          # Get current order and prepend events.id if needed
          current_order = events.order_values
          if current_order.empty? || current_order.first.to_sql != 'events.id'
            # Prepend events.id to the order
            events = events.reorder('events.id', *current_order)
          end
          # Apply DISTINCT ON and convert to array to avoid count issues
          events = events.select('DISTINCT ON (events.id) events.*')
        end

        # Limit results
        limit = [params[:limit]&.to_i || 100, 500].min
        # Convert to array to avoid ActiveRecord count issues with DISTINCT ON
        events_array = events.limit(limit).to_a
        events_array
      end

      def fetch_stories
        moments = Moment.for_feed
                        .includes(:user, :venue, :event)
                        .where('venue_id IS NOT NULL OR event_id IS NOT NULL')

        # Public audience only when not authenticated
        moments = moments.where(audience: 'public') unless current_user

        limit = [params[:stories_limit]&.to_i || params[:limit]&.to_i || 50, 200].min
        moments.order(created_at: :desc).limit(limit * 3).to_a
      end

      def bounding_box_provided?
        params[:north].present? && params[:south].present? && 
        params[:east].present? && params[:west].present?
      end

      def radius_search_provided?
        params[:center_latitude].present? && params[:center_longitude].present?
      end

      def base_url
        request&.base_url || ENV['API_BASE_URL'] || 'https://vibesapp.digital4design.com'
      end

      def calculate_bounds(items)
        return nil if items.empty?

        lats = []
        lngs = []

        items.each do |item|
          if item.is_a?(Venue)
            if item.coordinates?
              lats << item.latitude
              lngs << item.longitude
            end
          elsif item.is_a?(Event)
            location = item.event_location
            if location
              lats << location[:latitude]
              lngs << location[:longitude]
            end
          elsif item.is_a?(Moment)
            location = item.story_location
            if location
              lats << location[:latitude]
              lngs << location[:longitude]
            end
          end
        end

        return nil if lats.empty? || lngs.empty?

        {
          north: lats.max,
          south: lats.min,
          east: lngs.max,
          west: lngs.min,
          center: {
            latitude: (lats.max + lats.min) / 2.0,
            longitude: (lngs.max + lngs.min) / 2.0
          }
        }
      end

      def map_venue_response(venue)
        immersive = latest_immersive_story_for_venue(venue)
        immersive_360 = immersive.present? && immersive.projection == 'equirectangular'
        immersive_thumb = immersive.present? ? api_v1_moment_thumbnail_url(immersive).to_s : nil
        payload = {
          id: venue.id,
          type: 'venue',
          name: venue.name,
          coordinates: {
            latitude: venue.latitude.to_f,
            longitude: venue.longitude.to_f
          },
          address: {
            city: venue.city,
            country: venue.country,
            full_address: venue.full_address
          },
          image_url: venue.image_url(host: base_url),
          images: venue.has_image? ? [venue.image_url(host: base_url)].compact : [],
          rating: {
            average: venue.average_rating,
            count: venue.ratings_count
          },
          likes_count: venue.likes_count,
          status: venue.status,
          viewer_360_url: immersive ? viewer_360_url_for_moment(immersive) : nil,
          immersive_video_available: immersive.present?,
          immersive_is_360_degree: immersive_360,
          immersive_is_360_thumbnail: immersive_thumb,
          immersive_fallback: immersive.present? ? nil : venue_immersive_fallback(venue),
          stories: venue_stories_for_map(venue)
        }

        if params[:show_venue_events].to_s == 'true'
          payload[:events] = venue_events_for_map(venue)
        end

        payload
      end

      def venue_stories_for_map(venue)
        scope = Moment.for_feed.where(venue_id: venue.id).includes(:user)
        scope = scope.where(audience: 'public') unless current_user
        scope.map { |m| map_story_response(m) }.compact
      end

      def venue_events_for_map(venue)
        limit = [params[:venue_events_limit]&.to_i || 5, 20].min

        scope = venue.events
                     .includes(
                       :venue,
                       :creator,
                       moments: [:user, { image_attachment: :blob }, { video_attachment: :blob }],
                       poster_attachment: :blob,
                       photos_attachments: :blob
                     )
                     .where(status: %w[published live completed])
                     .order(starts_at: :desc)

        unless current_user && (current_user.role_venue_manager? || current_user.role_admin?)
          scope = scope.where(visibility: 'public')
        end

        scope.limit(limit).map do |event|
          map_event_response(event)
        end.compact
      end

      def map_event_response(event)
        location = event.event_location
        return nil unless location

        immersive = latest_immersive_story_for_event(event)
        immersive_360 = immersive.present? && immersive.projection == 'equirectangular'
        immersive_thumb = immersive.present? ? api_v1_moment_thumbnail_url(immersive).to_s : nil
        {
          id: event.id,
          type: 'event',
          title: event.creator&.name || event.title,
          posted_by: event.creator&.name,
          coordinates: {
            latitude: location[:latitude],
            longitude: location[:longitude]
          },
          starts_at: event.starts_at,
          ends_at: event.ends_at,
          status: event.status,
          category: event.category,
          is_live: event.is_live?,
          is_upcoming: event.is_upcoming?,
          price: event.price,
          currency: event.currency,
          is_free: event.is_free,
          poster_url: event.poster_image_url(host: base_url),
          images: ([event.poster_image_url(host: base_url)] + event.photo_urls_array(host: base_url)).compact.uniq,
          address: {
            city: event.event_city,
            country: event.event_country,
            full_address: event.full_address
          },
          venue: {
            id: event.venue.id,
            name: event.venue.name
          },
          viewer_360_url: immersive ? viewer_360_url_for_moment(immersive) : nil,
          immersive_video_available: immersive.present?,
          immersive_is_360_degree: immersive_360,
          immersive_is_360_thumbnail: immersive_thumb,
          bookings_count: event.bookings_count,
          likes_count: event.likes_count,
          interests_count: event.interests_count,
          stories: event_stories_for_map(event)
        }
      end

      def latest_immersive_story_for_venue(venue)
        Moment.for_feed
              .where(venue_id: venue.id, projection: 'equirectangular')
              .includes(video_attachment: :blob)
              .order(created_at: :desc)
              .detect { |m| m.video.attached? }
      end

      def latest_immersive_story_for_event(event)
        Moment.for_feed
              .where(event_id: event.id, projection: 'equirectangular')
              .includes(video_attachment: :blob)
              .order(created_at: :desc)
              .detect { |m| m.video.attached? }
      end

      # When a venue has no equirectangular immersive clip, supply a preview:
      # latest eligible event poster at the venue, else latest feed moment (story) with media.
      def venue_immersive_fallback(venue)
        event = latest_event_with_poster_for_venue(venue)
        if event
          return {
            source: 'event_poster',
            event_id: event.id,
            event_title: event.title,
            poster_url: event.poster_image_url(host: base_url),
            starts_at: event.starts_at&.iso8601,
            immersive_is_360_degree: false
          }
        end

        moment = latest_feed_moment_with_media_for_venue(venue)
        if moment
          thumb = if moment.video.attached?
                    api_v1_moment_thumbnail_url(moment)
                  elsif moment.image.attached?
                    url_for(moment.image)
                  end
          media_url = if moment.video.attached?
                        url_for(moment.video)
                      elsif moment.image.attached?
                        url_for(moment.image)
                      end
          return {
            source: 'story',
            moment_id: moment.id,
            media_type: moment.media_type,
            thumbnail_url: thumb.to_s,
            url: media_url.to_s,
            projection: moment.projection,
            immersive_is_360_degree: moment.projection == 'equirectangular',
            created_at: moment.created_at&.iso8601
          }
        end

        nil
      end

      def latest_event_with_poster_for_venue(venue)
        rel = venue.events
                     .includes(poster_attachment: :blob)
                     .where(status: %w[published completed])
                     .order(starts_at: :desc)
        unless current_user && (current_user.role_venue_manager? || current_user.role_admin?)
          rel = rel.where(visibility: 'public')
        end
        rel.limit(50).find { |e| e.has_poster? }
      end

      def latest_feed_moment_with_media_for_venue(venue)
        rel = Moment.for_feed
                    .where(venue_id: venue.id)
                    .includes(:user, image_attachment: :blob, video_attachment: :blob)
        rel = rel.where(audience: 'public') unless current_user
        rel.order(created_at: :desc).limit(50).detect { |m| m.image.attached? || m.video.attached? }
      end

      def viewer_360_url_for_moment(moment)
        return nil unless moment&.video&.attached?
        video_url = url_for(moment.video)
        "#{base_url}/venue_360_viewer.html?url=#{CGI.escape(video_url.to_s)}"
      end

      def event_stories_for_map(event)
        scope = event.moments.for_feed
        scope = scope.where(audience: 'public') unless current_user
        scope.map { |m| map_story_response(m) }.compact
      end

      def map_story_response(moment)
        location = moment.story_location
        return nil unless location

        media_type = moment.media_type
        url = if moment.video.attached?
                url_for(moment.video)
              elsif moment.image.attached?
                url_for(moment.image)
              else
                nil
              end
        return nil unless url

        thumbnail = if moment.video.attached?
                      # Use custom thumbnail endpoint to guarantee JPEG (Content-Type: image/jpeg)
                      api_v1_moment_thumbnail_url(moment)
                    elsif moment.image.attached?
                      url_for(moment.image)
                    else
                      ''
                    end

        {
          id: moment.id,
          type: media_type,
          thumbnail: thumbnail.to_s,
          url: url,
          coordinates: {
            latitude: location[:latitude],
            longitude: location[:longitude]
          },
          venue_id: moment.venue_id,
          event_id: moment.event_id,
          user: moment.user ? {
            id: moment.user.id,
            name: moment.user.name,
            username: moment.user.username,
            avatar_url: moment.user.respond_to?(:avatar_url) && moment.user.avatar_url.present? ? moment.user.avatar_url : default_avatar_url
          } : nil,
          created_at: moment.created_at&.iso8601,
          expires_at: moment.expires_at&.iso8601
        }
      end
    end
  end
end

