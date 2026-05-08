module Api
  module V1
    class SearchController < ApplicationController
      before_action :require_authentication!
      
      # GET /api/v1/search
      def index
        query = params[:q] || params[:query]
        tag = params[:tag].to_s.strip.presence
        country = params[:country].to_s.strip.presence
        limit_per_type = [params[:limit]&.to_i || 10, 50].min
        
        # If no query/tag provided, return trending events for the search landing page
        if query.blank? && tag.blank?
          events = Event.includes(:venue)
                        .published
                        .public_events
                        .upcoming
                        .left_joins(:bookings, :likes)
                        .group('events.id')
                        .order(Arel.sql('COUNT(bookings.id) + COUNT(likes.id) DESC'))
                        .limit(limit_per_type)

          results = {
            events: events.map { |event| event_search_result(event) },
            venues: [],
            users: [],
            artists: []
          }

          api_success(
            data: {
              query: nil,
              tag: nil,
              total_results: results[:events].count,
              results: results,
              tags: search_tags_for_response(country),
              counts: {
                events: results[:events].count,
                venues: 0,
                users: 0,
                artists: 0
              }
            },
            status: :ok
          )
          return
        end

        search_term = query.present? ? "%#{query}%" : nil
        results = {
          events: [],
          venues: [],
          users: [],
          artists: []
        }
        
        # Determine what to search
        types = params[:types] || ['events', 'venues']
        types = Array(types) if types.is_a?(String)
        
        # Search Events
        if types.include?('events')
          events = Event.includes(:venue)
                       .published
                       .public_events

          if search_term.present?
            events = events.where("events.title ILIKE ? OR events.description ILIKE ? OR events.category ILIKE ?",
                                  search_term, search_term, search_term)
          end

          # Filter by tag (slug from event_tags)
          if tag.present? && tag.downcase != 'all'
            events = apply_tag_filter(events, tag, country)
          end

          # Apply additional filters if provided
          if params[:event_category].present? && !params[:event_category].map(&:downcase).include?('all')
            events = events.where(category: params[:event_category])
          end

          if params[:event_city].present?
            events = events.joins(:venue).where(venues: { city: params[:event_city] })
          end

          if params[:event_time_filter] == 'upcoming'
            events = events.upcoming
          elsif params[:event_time_filter] == 'live'
            events = events.live
          end

          # Default ordering: soonest first; override to popularity if explicitly requested
          if params[:sort_by].to_s == 'popularity'
            events = events.left_joins(:bookings, :likes)
                           .group('events.id')
                           .order(Arel.sql('COUNT(bookings.id) + COUNT(likes.id) DESC'))
          else
            events = events.order(starts_at: :asc)
          end

          events = events.limit(limit_per_type)
          
          results[:events] = events.map { |event| event_search_result(event) }
        end
        
        # Search Venues
        if types.include?('venues')
          venues = Venue.active
                       .where("venues.name ILIKE ? OR venues.description ILIKE ? OR venues.city ILIKE ? OR venues.country ILIKE ?",
                              search_term, search_term, search_term, search_term)
          
          # Apply additional filters if provided
          if params[:venue_city].present?
            venues = venues.where(city: params[:venue_city])
          end
          
          if params[:venue_country].present?
            venues = venues.where(country: params[:venue_country])
          end
          
          venues = venues.order(created_at: :desc).limit(limit_per_type)
          
          results[:venues] = venues.map do |venue|
            {
              id: venue.id,
              type: 'venue',
              name: venue.name,
              description: venue.description,
              city: venue.city,
              country: venue.country,
              address: {
                full_address: venue.full_address
              },
              location: venue.coordinates? ? {
                latitude: venue.latitude,
                longitude: venue.longitude
              } : nil,
              rating: {
                average: venue.average_rating,
                count: venue.ratings_count
              },
              image_url: venue.image_url(host: request.base_url),
              likes_count: venue.likes_count,
              followers_count: venue.followers_count,
              user_liked: venue.user_liked?(current_user),
              user_following: venue.user_following?(current_user)
            }
          end
        end
        
        # Search Users (if enabled)
        if types.include?('users')
          base_query = User.active
                     .where("users.name ILIKE ? OR users.username ILIKE ?", search_term, search_term)
                           .where.not(id: current_user.id)
                           .order(created_at: :desc)
          
          # Separate users and artists, limit each type
          users_list = base_query.where.not(role: 'artist').limit(limit_per_type)
          artists_list = base_query.where(role: 'artist').limit(limit_per_type)
          
          results[:users] = users_list.map do |user|
            avatar_url = if user.respond_to?(:avatar_url) && user.avatar_url.present?
                          # Convert relative path to full URL if needed
                          if user.avatar_url.start_with?('http')
                            user.avatar_url
                          else
                            "#{request.base_url}#{user.avatar_url}"
                          end
                        else
                          default_avatar_url
                        end
            
            follow_status = get_follow_request_status(user)
            
            {
              id: user.id,
              type: 'user',
              name: user.name,
              username: user.username,
              role: user.role,
              avatar_url: avatar_url,
              bio: user.respond_to?(:bio) ? user.bio : nil,
              followers_count: user.followers_count,
              following_count: user.following_count,
              is_following: current_user.following?(user),
              is_followed_by: current_user.followed_by?(user),
              has_pending_request_to: follow_status[:has_pending_request_to],
              has_pending_request_from: follow_status[:has_pending_request_from],
              pending_request_id: follow_status[:pending_request_id],
              pending_request_to_id: follow_status[:pending_request_to_id]
            }
          end
          
          results[:artists] = artists_list.map do |artist|
            avatar_url = if artist.respond_to?(:avatar_url) && artist.avatar_url.present?
                          # Convert relative path to full URL if needed
                          if artist.avatar_url.start_with?('http')
                            artist.avatar_url
                          else
                            "#{request.base_url}#{artist.avatar_url}"
                          end
                        else
                          default_avatar_url
                        end
            
            follow_status = get_follow_request_status(artist)
            
            {
              id: artist.id,
              type: 'artist',
              name: artist.name,
              username: artist.username,
              role: artist.role,
              avatar_url: avatar_url,
              bio: artist.respond_to?(:bio) ? artist.bio : nil,
              followers_count: artist.followers_count,
              following_count: artist.following_count,
              is_following: current_user.following?(artist),
              is_followed_by: current_user.followed_by?(artist),
              has_pending_request_to: follow_status[:has_pending_request_to],
              has_pending_request_from: follow_status[:has_pending_request_from],
              pending_request_id: follow_status[:pending_request_id],
              pending_request_to_id: follow_status[:pending_request_to_id],
              categories: artist.role_artist? ? artist.categories.map { |c| { id: c.id, name: c.name, slug: c.slug } } : []
            }
          end
        end
        
        # Tags (default + trending) for filter chips
        tags = search_tags_for_response(country)

        # Calculate totals
        total_results = results[:events].count + results[:venues].count + results[:users].count + results[:artists].count

        api_success(
          data: {
            query: query,
            tag: tag,
            total_results: total_results,
            results: results,
            tags: tags,
            counts: {
              events: results[:events].count,
              venues: results[:venues].count,
              users: results[:users].count,
              artists: results[:artists].count
            }
          },
          status: :ok
        )
      end
      
      private

      def event_search_result(event)
        {
          id: event.id,
          type: 'event',
          title: event.title,
          description: event.description,
          category: event.category,
          starts_at: event.starts_at,
          ends_at: event.ends_at,
          status: event.status,
          is_live: event.is_live?,
          is_upcoming: event.is_upcoming?,
          bookings_count: event.bookings_count,
          likes_count: event.likes_count,
          interests_count: event.interests_count,
          followers_count: event.interests_count, # Using interests as followers
          user_booked: event.user_booked?(current_user),
          user_liked: event.user_liked?(current_user),
          user_interested: event.user_interested?(current_user),
          poster_image_url: event.poster_image_url(host: request.base_url),
          venue: {
            id: event.venue.id,
            name: event.venue.name,
            city: event.venue.city,
            country: event.venue.country
          }
        }
      end

      def apply_tag_filter(events, tag_slug, country = nil)
        slug = tag_slug.to_s.parameterize
        event_tag = EventTag.where(slug: slug)
                           .where('country IS NULL OR country = ?', country.to_s)
                           .order(Arel.sql('CASE WHEN country IS NOT NULL THEN 0 ELSE 1 END'))
                           .first
        return events unless event_tag

        if event_tag.category_slug.present?
          cat = Category.find_by(slug: event_tag.category_slug)
          if cat
            events = events.by_category_slugs([event_tag.category_slug])
          else
            legacy = { 'festival' => 'Festivals', 'party' => 'Party Events' }[event_tag.slug]
            events = events.where(category: legacy) if legacy
          end
        else
          cat_name = Event::CATEGORIES.find { |c| c.parameterize == event_tag.slug }
          events = events.where(category: cat_name) if cat_name
        end
        events
      end

      def search_tags_for_response(country)
        tags = []
        tags += EventTag.default.global.ordered.map { |t| { id: t.id, slug: t.slug, name: t.name, source: 'default' } }
        tags += EventTag.for_country(country).ordered.map { |t| { id: t.id, slug: t.slug, name: t.name, source: 'country', country: t.country } } if country.present?
        tags += trending_tags_for_search(country).map { |t| { slug: t.slug, name: t.name, source: 'trending', events_count: t.events_count } }
        tags
      end

      def trending_tags_for_search(country)
        now = Time.current
        window_end = 30.days.from_now
        events = Event.published
                     .where('starts_at >= ? AND starts_at <= ?', now, window_end)
                     .joins(:venue)
        events = events.where(venues: { country: country }) if country.present?

        by_legacy = events.where.not(category: [nil, '']).group(:category).count
        by_category = events.joins(event_categories: :category).group('categories.slug').count

        merged = {}
        by_legacy.each { |cat_name, count| merged[cat_name.to_s.parameterize] = (merged[cat_name.to_s.parameterize] || 0) + count }
        by_category.each { |slug, count| merged[slug.to_s] = (merged[slug.to_s] || 0) + count }

        merged.sort_by { |_, c| -c }.first(5).map do |slug, count|
          OpenStruct.new(slug: slug, name: slug.titleize, events_count: count)
        end
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
    end
  end
end

