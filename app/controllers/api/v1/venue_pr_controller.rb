# frozen_string_literal: true

module Api
  module V1
    class VenuePrController < ApplicationController
      before_action :require_authentication!
      before_action :set_venue, only: [:show, :create, :scan_qr, :stop_partnership]
      before_action :check_venue_ownership, only: [:create, :scan_qr, :stop_partnership]

      # GET /api/v1/venues/:venue_id/pr
      def show
        master = @venue.master_pr_partnership
        juniors = @venue.junior_pr_partnerships.includes(:user).order(created_at: :asc)

        api_success(
          data: {
            master_pr: master ? pr_partnership_response(master) : nil,
            junior_prs: juniors.map { |p| pr_partnership_response(p) },
            pr_venues: []
          },
          status: :ok
        )
      end

      # POST /api/v1/venues/:venue_id/pr
      def create
        user_id = params[:user_id] || params[:pr][:user_id]
        role = (params[:role] || params[:pr][:role] || 'junior_pr').to_s
        role = 'junior_pr' unless VenuePrPartnership::ROLES.include?(role)

        if user_id.blank?
          api_error(message: 'user_id is required', status: :unprocessable_entity)
          return
        end

        pr_user = User.find_by(id: user_id)
        unless pr_user
          api_error(message: 'PR user not found', status: :not_found)
          return
        end

        # Same user cannot have another active partnership with this venue
        existing = @venue.venue_pr_partnerships.active.find_by(user_id: pr_user.id)
        if existing
          api_error(message: 'This user is already an active PR for this venue', status: :unprocessable_entity)
          return
        end

        if role == 'master_pr'
          # Replace existing master: end current master then create new one
          @venue.master_pr_partnership&.end_partnership!
        end

        partnership = @venue.venue_pr_partnerships.build(user: pr_user, role: role, status: 'active')

        if partnership.save
          api_success(
            data: { pr: pr_partnership_response(partnership) },
            message: 'PR assigned successfully',
            status: :created
          )
        else
          api_validation_error(errors: partnership.errors.full_messages)
        end
      end

      # POST /api/v1/venues/:venue_id/pr/scan_qr
      # Venue scans PR profile QR code and adds user as PR (junior_pr by default).
      # Body: { "user_id": "uuid" } OR { "url": "vibes://users/uuid" } OR { "qr_data": "{\"type\":\"User\",\"url\":\"vibes://users/uuid\"}" }
      def scan_qr
        user_id = extract_user_id_from_scan_params
        if user_id.blank?
          api_error(
            message: 'Could not extract user from QR. Provide user_id, url (vibes://users/:id), or qr_data (JSON from QR)',
            status: :bad_request
          )
          return
        end

        params[:user_id] = user_id
        params[:role] = params[:role].presence || 'junior_pr'
        create
      end

      # POST /api/v1/venues/:venue_id/pr/stop_partnership
      # Body: { "partnership_id": "uuid" } to end a specific PR; or omit to end master (legacy).
      def stop_partnership
        partnership_id = params[:partnership_id] || params[:pr]&.dig(:partnership_id)
        partnership = if partnership_id.present?
                        @venue.venue_pr_partnerships.active.find_by(id: partnership_id)
                      else
                        @venue.master_pr_partnership
                      end

        unless partnership
          api_error(
            message: partnership_id.present? ? 'Partnership not found or not active for this venue' : 'No active master PR for this venue',
            status: :unprocessable_entity
          )
          return
        end

        partnership.end_partnership!
        # Return current PR state after removal
        master = @venue.master_pr_partnership
        juniors = @venue.junior_pr_partnerships.includes(:user).order(created_at: :asc)
        api_success(
          data: {
            master_pr: master ? pr_partnership_response(master) : nil,
            junior_prs: juniors.map { |p| pr_partnership_response(p) }
          },
          message: 'Partnership ended successfully',
          status: :ok
        )
      end

      # GET /api/v1/users/me/pr_venues (current user as PR: list my venues)
      def my_pr_venues
        partnerships = current_user.active_pr_partnerships.includes(:venue).order(created_at: :desc)
        api_success(
          data: {
            pr_venues: partnerships.map { |p| pr_venue_entry_response(p) }
          },
          status: :ok
        )
      end

      # GET /api/v1/users/me/pr/events — events at venues where current user is an active PR
      # Query: venue_id (optional, must be one of your PR venues), limit, offset
      def my_pr_events
        venue_ids = current_user.active_pr_partnerships.pluck(:venue_id)
        if venue_ids.empty?
          api_success(
            data: { events: [], pagination: { limit: 20, offset: 0, total_count: 0, has_more: false } },
            status: :ok
          )
          return
        end

        if params[:venue_id].present?
          vid = params[:venue_id].to_s
          unless venue_ids.map(&:to_s).include?(vid)
            api_error(message: 'Not a PR venue for you', status: :forbidden)
            return
          end
          venue_ids = [vid]
        end

        scope = Event.where(venue_id: venue_ids)
                     .includes(
                       { venue: :owner },
                       :creator,
                       :event_custom_categories,
                       :event_ticket_types,
                       :event_tags,
                       :ratings,
                       :vibe_checks
                     )
                     .order(starts_at: :desc)
        limit = [params[:limit]&.to_i || 20, 100].min
        offset = params[:offset]&.to_i || 0
        total_count = scope.count
        events = scope.limit(limit).offset(offset)

        api_success(
          data: {
            events: events.map { |e| pr_event_summary(e, request: request) },
            filters_applied: {},
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

      # GET /api/v1/users/:user_id/pr_venues (list venues for a PR user; public or restricted)
      def pr_venues
        pr_user = User.find_by(id: params[:user_id])
        unless pr_user
          api_error(message: 'User not found', status: :not_found)
          return
        end

        partnerships = pr_user.active_pr_partnerships.includes(:venue).order(created_at: :desc)
        api_success(
          data: {
            pr: user_basic_response(pr_user),
            pr_venues: partnerships.map { |p| pr_venue_entry_response(p) }
          },
          status: :ok
        )
      end

      # GET /api/v1/venue_pr/search?q=... (search users to assign as PR)
      def search
        q = params[:q].to_s.strip
        if q.length < 2
          api_error(message: 'Search query must be at least 2 characters', status: :bad_request)
          return
        end

        users = User.active
                   .where('username ILIKE :q OR name ILIKE :q OR email ILIKE :q', q: "%#{q}%")
                   .limit(20)
        api_success(
          data: {
            users: users.map { |u| user_basic_response(u) }
          },
          status: :ok
        )
      end

      private

      def extract_user_id_from_scan_params
        # Direct user_id
        uid = params[:user_id].presence || params.dig(:pr, :user_id)
        return uid if uid.present?

        # URL: vibes://users/:id
        url = params[:url].presence || params.dig(:pr, :url)
        if url.present?
          m = url.match(%r{vibes://users/([a-f0-9\-]+)}i)
          return m[1] if m
        end

        # Raw QR JSON: { "type": "User", "url": "vibes://users/:id" }
        qr_data = params[:qr_data].presence || params.dig(:pr, :qr_data)
        return nil if qr_data.blank?

        parsed = JSON.parse(qr_data.to_s) rescue nil
        return nil unless parsed.is_a?(Hash)

        url_from_qr = parsed['url'] || parsed[:url]
        if url_from_qr.present?
          m = url_from_qr.to_s.match(%r{vibes://users/([a-f0-9\-]+)}i)
          return m[1] if m
        end

        parsed['user_id']&.to_s || parsed[:user_id]&.to_s || parsed['id']&.to_s || parsed[:id]&.to_s
      end

      def set_venue
        @venue = Venue.find_by(id: params[:venue_id] || params[:id])
        unless @venue
          api_error(message: 'Venue not found', status: :not_found)
          return
        end
      end

      def check_venue_ownership
        unless @venue.owner_id == current_user.id || current_user.role_admin?
          api_error(message: 'Only the venue owner can manage PR', status: :forbidden)
          return
        end
      end

      def pr_partnership_response(partnership)
        {
          id: partnership.id,
          user: user_basic_response(partnership.user),
          role: partnership.role,
          status: partnership.status,
          rating: nil, # Placeholder; add PR rating if you have rateable User
          created_at: partnership.created_at,
          ended_at: partnership.ended_at
        }
      end

      def pr_venue_entry_response(partnership)
        {
          id: partnership.id,
          venue: venue_summary_response(partnership.venue),
          role: partnership.role,
          status: partnership.status,
          created_at: partnership.created_at
        }
      end

      def venue_summary_response(venue)
        {
          id: venue.id,
          name: venue.name,
          city: venue.city,
          country: venue.country,
          image_url: venue.respond_to?(:image_url) ? venue.image_url : nil
        }
      end

      def user_basic_response(user)
        {
          id: user.id,
          username: user.username,
          name: user.name,
          role: user.role,
          avatar_url: user.respond_to?(:avatar_url) && user.avatar_url.present? ? user.avatar_url : default_avatar_url
        }
      end

      # Return the same shape as EventsController#event_response for PR users.
      def pr_event_summary(event, request: nil)
        event_response_for_pr(event, request: request)
      end

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

      # Build address details - returns venue address when event doesn't override
      def build_event_address_details(event)
        uses_venue_address = !event.location_overridden?

        if uses_venue_address
          venue = event.venue
          {
            address1: venue&.address1,
            address2: venue&.address2,
            city: venue&.city,
            region: venue&.region,
            postal_code: venue&.postal_code,
            country: venue&.country,
            latitude: venue&.latitude,
            longitude: venue&.longitude,
            uses_venue_address: true
          }
        else
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

      def event_response_for_pr(event, request: nil)
        average_rating =
          event.ratings.approved.average(:rating)&.round(2) ||
          event.vibe_check_rating ||
          nil
        ratings_count = event.ratings.approved.count + event.vibe_checks_count

        base_url = request&.base_url || ENV['API_BASE_URL'] || 'https://vibesapp.digital4design.com'

        collaborator_payload =
          if event.collaborator
            {
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
              rsvp_enabled: event.venue.rsvp_enabled != false
            }
          end

        posted_by_payload =
          if event.venue&.owner
            {
              id: event.venue.owner.id,
              name: event.venue.owner.name,
              username: event.venue.owner.username
            }
          end

        creator_payload =
          if event.creator
            {
              id: event.creator.id,
              name: event.creator.name,
              username: event.creator.username,
              role: event.creator.role
            }
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
          attendance_mode: event.attendance_mode || 'rsvp',
          tickets_closed: event.tickets_closed?,
          ticket_sales_open: event.ticket_sales_open?,
          rsvp_allowed: event.rsvp_changes_allowed?,
          venue_rsvp_enabled: event.venue_rsvp_enabled?,
          ticket_types: event.event_ticket_types.sort_by { |t| [t.display_order, t.id] }.map { |t|
            detail = event_ticket_type_payload(t, event)
            detail.merge(ticket_type: detail.deep_dup)
          },
          pr_commission_type: event.pr_commission_type,
          pr_commission_percentage: event.pr_commission_percentage,
          created_at: event.created_at,
          updated_at: event.updated_at
        }
      end
    end
  end
end
