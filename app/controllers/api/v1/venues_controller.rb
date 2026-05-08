module Api
  module V1
    class VenuesController < ApplicationController
      before_action :require_authentication!, except: [:share_qr]
      before_action :set_venue, only: [:show, :update, :destroy, :rsvp, :remove_rsvp, :check_rsvp, :list_rsvps, :follow, :unfollow, :check_follow, :upload_image, :share_qr, :venue_categories, :replace_venue_categories]
      before_action :check_ownership, only: [:update, :destroy, :upload_image, :replace_venue_categories]
      
      # GET /api/v1/venues
      def index
        venues = if params[:my_venues] == 'true' || current_user&.role_venue_manager?
                   current_user.venues.active
                 else
                   Venue.active
                 end
        
        # Filter by city
        venues = venues.by_city(params[:city]) if params[:city].present?
        
        # Filter by country
        venues = venues.by_country(params[:country]) if params[:country].present?
        
        # Search by name
        if params[:search].present?
          venues = venues.where("name ILIKE ?", "%#{params[:search]}%")
        end
        
        # Limit results
        limit = [params[:limit]&.to_i || 20, 100].min
        offset = params[:offset]&.to_i || 0
        total_count = venues.count
        venues = venues.order(created_at: :desc).limit(limit).offset(offset)
        
        api_success(
          data: {
            venues: venues.map { |venue| venue_response(venue, request: request) },
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
      
      # GET /api/v1/venues/:id
      def show
        api_success(data: { venue: venue_response(@venue, request: request) }, status: :ok)
      end
      
      # POST /api/v1/venues
      def create
        # Only venue_manager and admin can create venues
        unless current_user.role_venue_manager? || current_user.role_admin?
          api_error(message: 'Only venue managers and admins can create venues', status: :forbidden)
          return
        end

        category_ids_param = params.dig(:venue, :category_ids)
        if category_ids_param.present?
          err = validate_venue_category_ids(category_ids_param)
          if err
            api_error(message: err, status: :bad_request)
            return
          end
        end

        venue = current_user.venues.build(venue_params)

        if venue.save
          apply_venue_categories(venue, category_ids_param) if params[:venue].key?(:category_ids)
          api_success(
            data: { venue: venue_response(venue.reload, request: request) },
            message: 'Venue created successfully',
            status: :created
          )
        else
          api_validation_error(errors: venue.errors.full_messages)
        end
      end
      
      # PATCH/PUT /api/v1/venues/:id
      def update
        category_ids_param = params.dig(:venue, :category_ids)
        if category_ids_param.present?
          err = validate_venue_category_ids(category_ids_param)
          if err
            api_error(message: err, status: :bad_request)
            return
          end
        end

        if @venue.update(venue_params)
          apply_venue_categories(@venue, category_ids_param) if params[:venue].key?(:category_ids)
          api_success(
            data: { venue: venue_response(@venue.reload, request: request) },
            message: 'Venue updated successfully',
            status: :ok
          )
        else
          api_validation_error(errors: @venue.errors.full_messages)
        end
      end
      
      # DELETE /api/v1/venues/:id
      def destroy
        if @venue.destroy
          api_success(message: 'Venue deleted successfully', status: :ok)
        else
          api_validation_error(errors: @venue.errors.full_messages)
        end
      end

      # POST /api/v1/venues/:id/rsvp
      def rsvp
        # Get or create RSVP
        interest = @venue.venue_interests.find_or_initialize_by(user: current_user)
        
        # Update RSVP status and details
        interest.rsvp_status = params[:rsvp_status] || 'yes'
        interest.guest_count = params[:guest_count]&.to_i || 0
        interest.notes = params[:notes] if params[:notes].present?
        
        if interest.save
          api_success(
            data: {
              venue_id: @venue.id,
              venue_name: @venue.name,
              rsvp: venue_rsvp_response(interest),
              rsvp_stats: {
                yes_count: @venue.rsvp_yes_count,
                no_count: @venue.rsvp_no_count,
                maybe_count: @venue.rsvp_maybe_count,
                total_interested: @venue.interests_count
              }
            },
            message: 'RSVP updated successfully',
            status: interest.persisted? ? :ok : :created
          )
        else
          api_validation_error(errors: interest.errors.full_messages)
        end
      rescue => e
        Rails.logger.error "Venue RSVP Error: #{e.message}"
        api_error(message: 'Failed to update RSVP', status: :internal_server_error)
      end

      # DELETE /api/v1/venues/:id/rsvp
      def remove_rsvp
        interest = @venue.venue_interests.find_by(user: current_user)
        
        if interest.nil?
          api_error(message: 'You have not RSVP\'d to this venue', status: :not_found)
          return
        end
        
        if interest.destroy
          api_success(
            data: {
              venue_id: @venue.id,
              venue_name: @venue.name,
              rsvp: nil,
              rsvp_stats: {
                yes_count: @venue.rsvp_yes_count,
                no_count: @venue.rsvp_no_count,
                maybe_count: @venue.rsvp_maybe_count,
                total_interested: @venue.interests_count
              }
            },
            message: 'RSVP removed successfully',
            status: :ok
          )
        else
          api_error(message: 'Failed to remove RSVP', status: :internal_server_error)
        end
      rescue => e
        Rails.logger.error "Remove Venue RSVP Error: #{e.message}"
        api_error(message: 'Failed to remove RSVP', status: :internal_server_error)
      end

      # GET /api/v1/venues/:id/rsvp/check
      def check_rsvp
        interest = @venue.venue_interests.find_by(user: current_user)
        
        api_success(
          data: {
            venue_id: @venue.id,
            venue_name: @venue.name,
            rsvp: interest ? venue_rsvp_response(interest) : nil,
            has_rsvp: interest.present?,
            rsvp_stats: {
              yes_count: @venue.rsvp_yes_count,
              no_count: @venue.rsvp_no_count,
              maybe_count: @venue.rsvp_maybe_count,
              total_interested: @venue.interests_count
            }
          },
          status: :ok
        )
      end

      # GET /api/v1/venues/:id/rsvps
      def list_rsvps
        # Filter by RSVP status
        interests = @venue.venue_interests.includes(:user)
        interests = interests.where(rsvp_status: params[:rsvp_status]) if params[:rsvp_status].present?
        
        limit = [params[:limit]&.to_i || 20, 100].min
        offset = params[:offset]&.to_i || 0
        total_count = interests.count
        
        interests = interests.order(responded_at: :desc, created_at: :desc)
                            .limit(limit)
                            .offset(offset)
        
        api_success(
          data: {
            venue_id: @venue.id,
            venue_name: @venue.name,
            rsvps: interests.map { |interest| venue_rsvp_response(interest, include_user: true) },
            rsvp_stats: {
              yes_count: @venue.rsvp_yes_count,
              no_count: @venue.rsvp_no_count,
              maybe_count: @venue.rsvp_maybe_count,
              total_interested: @venue.interests_count
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

      # POST /api/v1/venues/:id/follow
      def follow
        if current_user.following_venue?(@venue)
          api_error(message: 'You are already following this venue', status: :bad_request)
          return
        end
        
        if current_user.follow_venue!(@venue)
          api_success(
            data: {
              venue_id: @venue.id,
              venue_name: @venue.name,
              is_following: true,
              followers_count: @venue.followers_count
            },
            message: 'Successfully followed venue',
            status: :created
          )
        else
          api_error(message: 'Failed to follow venue', status: :internal_server_error)
        end
      rescue => e
        Rails.logger.error "Venue Follow Error: #{e.message}"
        api_error(message: 'Failed to follow venue', status: :internal_server_error)
      end
      
      # DELETE /api/v1/venues/:id/follow
      def unfollow
        unless current_user.following_venue?(@venue)
          api_error(message: 'You are not following this venue', status: :bad_request)
          return
        end
        
        if current_user.unfollow_venue!(@venue)
          api_success(
            data: {
              venue_id: @venue.id,
              venue_name: @venue.name,
              is_following: false,
              followers_count: @venue.followers_count
            },
            message: 'Successfully unfollowed venue',
            status: :ok
          )
        else
          api_error(message: 'Failed to unfollow venue', status: :internal_server_error)
        end
      rescue => e
        Rails.logger.error "Venue Unfollow Error: #{e.message}"
        api_error(message: 'Failed to unfollow venue', status: :internal_server_error)
      end
      
      # GET /api/v1/venues/:id/follow/check
      def check_follow
        api_success(
          data: {
            venue_id: @venue.id,
            venue_name: @venue.name,
            is_following: current_user.following_venue?(@venue),
            followers_count: @venue.followers_count
          },
          status: :ok
        )
      end

      # GET /api/v1/venues/my_followed
      def my_followed
        limit = [params[:limit]&.to_i || 20, 100].min
        offset = params[:offset]&.to_i || 0
        
        followed_venues = current_user.followed_venues.active
        total_count = followed_venues.count
        followed_venues = followed_venues.order(created_at: :desc).limit(limit).offset(offset)
        
        api_success(
          data: {
            venues: followed_venues.map { |venue| venue_response(venue, request: request) },
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
      
      # POST /api/v1/venues/:id/upload_image
      def upload_image
        venue_image = params[:image] || params[:file]
        
        if venue_image.blank?
          api_error(message: 'Image file is required', status: :bad_request)
          return
        end
        
        # Validate file type
        unless venue_image.content_type.in?(%w[image/jpeg image/jpg image/png image/gif image/webp])
          api_error(message: 'Invalid file type. Only JPEG, PNG, GIF, and WebP images are allowed', status: :bad_request)
          return
        end
        
        # Validate file size (max 10MB)
        if venue_image.size > 10.megabytes
          api_error(message: 'File size too large. Maximum size is 10MB', status: :bad_request)
          return
        end
        
        # Attach the file
        @venue.image.attach(venue_image)
        
        if @venue.image.attached?
          # Generate URL
          image_url = @venue.image_url(host: request.base_url)
          
          api_success(
            data: { 
              venue: venue_response(@venue, request: request),
              image_url: image_url
            },
            message: 'Venue image uploaded successfully',
            status: :ok
          )
        else
          api_error(message: 'Failed to upload venue image', status: :unprocessable_entity)
        end
      end
      
      # GET /api/v1/venues/:id/share_qr
      def share_qr
        require 'rqrcode'
        
        # Generate QR code for venue with type embedded
        venue_url = "vibes://venues/#{@venue.id}"
        qr_data = {
          type: "Venue",
          url: venue_url
        }.to_json
        qr = RQRCode::QRCode.new(qr_data)
        
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
                    filename: "venue_#{@venue.id}_qr.png"
          return
        end
        
        # Otherwise, return JSON with base64 encoded QR code
        api_success(
          data: {
            qr_code: Base64.strict_encode64(png.to_s),
            qr_image_url: "#{request.base_url}/api/v1/venues/#{@venue.id}/share_qr?format=image&size=#{size}",
            venue_url: venue_url,
            type: "Venue",
            venue: venue_response(@venue, request: request)
          },
          status: :ok
        )
      end

      # GET /api/v1/venue_categories
      # List all venue-type categories (restaurant, pub, cinema, etc.) - no venue_id required
      def list_venue_categories
        categories = Category.for_venues
                            .includes(:categories_group)
                            .order('categories_groups.display_order, categories.display_order')
        group = categories.first&.categories_group
        data = if group
          {
            categories_group: {
              id: group.id,
              name: group.name,
              slug: group.slug
            },
            categories: categories.map { |c| venue_category_item(c) }
          }
        else
          { categories_group: nil, categories: [] }
        end
        api_success(data: data, status: :ok)
      end

      # GET /api/v1/venues/:venue_id/categories
      # List venue-type categories only (restaurant, pub, cinema, etc.) with subscribed flag
      def venue_categories
        # Only categories from the venue-categories group (venue types)
        venue_type_categories = Category.for_venues
                                       .includes(:categories_group)
                                       .order('categories_groups.display_order, categories.display_order')
        
        # Get venue's subscribed category IDs for efficient lookup
        subscribed_category_ids = @venue.venue_categories.pluck(:category_id).to_set
        
        # Single group: "Venue type" with all venue-type categories
        group = venue_type_categories.first&.categories_group
        categories_groups_data = if group
          [{
            id: group.id,
            name: group.name,
            slug: group.slug,
            categories: venue_type_categories.map do |cat|
              venue_category_item(cat).merge(subscribed: subscribed_category_ids.include?(cat.id))
            end
          }]
        else
          []
        end
        
        api_success(
          data: {
            venue_id: @venue.id,
            categories_groups: categories_groups_data,
            subscribed_category_ids: subscribed_category_ids.to_a
          },
          status: :ok
        )
      end

      # PUT /api/v1/venues/:venue_id/categories
      # Replace all categories for a venue (only venue-type categories allowed). Empty array clears all.
      def replace_venue_categories
        category_ids = Array(params[:category_ids]).map(&:to_s).reject(&:blank?)

        unless category_ids.empty?
          allowed_ids = Category.for_venues.where(id: category_ids).pluck(:id).map(&:to_s)
          invalid_ids = category_ids - allowed_ids
          if invalid_ids.any?
            api_error(message: "Invalid or non-venue category IDs: #{invalid_ids.join(', ')}. Use categories from Venue type (e.g. restaurant, pub, cinema).", status: :bad_request)
            return
          end
          category_ids = allowed_ids
        end

        if @venue.replace_categories(category_ids, source: params[:source] || 'manual')
          api_success(
            data: {
              venue_id: @venue.id,
              categories: @venue.reload.all_categories,
              category_ids: @venue.category_ids
            },
            message: 'Categories updated successfully',
            status: :ok
          )
        else
          api_error(message: 'Failed to update categories', status: :internal_server_error)
        end
      end

      private
      
      def set_venue
        venue_id = params[:id] || params[:venue_id]
        @venue = Venue.find_by(id: venue_id)
        unless @venue
          api_error(message: 'Venue not found', status: :not_found)
          return
        end
      end
      
      def check_ownership
        unless @venue.owner_id == current_user.id || current_user.role_admin?
          api_error(message: 'You can only modify your own venues', status: :forbidden)
          return
        end
      end
      
      def venue_params
        params.require(:venue).permit(
          :name,
          :description,
          :address1,
          :address2,
          :city,
          :region,
          :country,
          :postal_code,
          :latitude,
          :longitude,
          :capacity,
          :contact_email,
          :contact_phone,
          :status,
          :default_currency,
          :rsvp_enabled,
          :image
        )
      end

      # Single venue category payload (id, name, slug, icon_key, icon, display_order).
      # icon is the same as icon_key for client asset lookup; add icon_url if you serve icons from API.
      def venue_category_item(category)
        {
          id: category.id,
          name: category.name,
          slug: category.slug,
          icon_key: category.icon_key,
          icon: category.icon_key,
          display_order: category.display_order
        }
      end

      # Returns nil if valid, or error string if invalid
      def validate_venue_category_ids(category_ids_param)
        ids = Array(category_ids_param).map(&:to_s).reject(&:blank?)
        return nil if ids.empty?
        allowed = Category.for_venues.where(id: ids).pluck(:id).map(&:to_s)
        invalid = ids - allowed
        invalid.any? ? "Invalid or non-venue category IDs: #{invalid.join(', ')}. Use categories from Venue type (e.g. restaurant, pub, cinema)." : nil
      end

      # Applies category_ids to venue (replace semantics). Pass nil to skip, [] to clear.
      def apply_venue_categories(venue, category_ids_param)
        ids = Array(category_ids_param).map(&:to_s).reject(&:blank?)
        allowed = Category.for_venues.where(id: ids).pluck(:id).map(&:to_s)
        venue.replace_categories(allowed, source: 'manual')
      end
      
      def venue_response(venue, request: nil)
        host = request&.base_url || ENV['API_BASE_URL'] || 'https://vibesapp.digital4design.com'
        {
          id: venue.id,
          name: venue.name,
          description: venue.description,
          address: {
            address1: venue.address1,
            address2: venue.address2,
            city: venue.city,
            region: venue.region,
            country: venue.country,
            postal_code: venue.postal_code,
            full_address: venue.full_address
          },
          location: venue.coordinates? ? {
            latitude: venue.latitude,
            longitude: venue.longitude
          } : nil,
          capacity: venue.capacity,
          contact: {
            email: venue.contact_email,
            phone: venue.contact_phone
          },
          status: venue.status,
          default_currency: venue.respond_to?(:default_currency) ? (venue.default_currency.presence || 'USD') : 'USD',
          rsvp_enabled: venue.respond_to?(:rsvp_enabled) ? venue.rsvp_enabled != false : true,
          rating: {
            average: venue.average_rating,
            count: venue.ratings_count
          },
          vibecheck_rate: venue.vibecheck_rate,
          image_url: venue.image_url(host: host),
          likes_count: venue.likes_count,
          user_liked: current_user ? venue.user_liked?(current_user) : false,
          user_rsvp_status: current_user ? venue.user_rsvp_status(current_user) : nil,
          interests_count: venue.interests_count,
          followers_count: venue.followers_count,
          events_count: venue.events.count,
          user_following: current_user ? venue.user_following?(current_user) : false,
          rsvp_stats: {
            yes_count: venue.rsvp_yes_count,
            no_count: venue.rsvp_no_count,
            maybe_count: venue.rsvp_maybe_count
          },
          categories: venue.all_categories,
          category_ids: venue.category_ids,
          owner: {
            id: venue.owner.id,
            name: venue.owner.name,
            email: venue.owner.email
          },
          created_at: venue.created_at,
          updated_at: venue.updated_at
        }
      end
      
      def venue_rsvp_response(interest, include_user: false)
        response = {
          id: interest.id,
          rsvp_status: interest.rsvp_status,
          guest_count: interest.guest_count,
          total_attendees: interest.total_attendees,
          notes: interest.notes,
          responded_at: interest.responded_at&.iso8601,
          created_at: interest.created_at.iso8601
        }
        
        if include_user
          response[:user] = {
            id: interest.user.id,
            name: interest.user.name,
            username: interest.user.username
          }
        end
        
        response
      end
    end
  end
end

