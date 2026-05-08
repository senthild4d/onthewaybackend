class Event < ApplicationRecord
  belongs_to :venue, optional: true
  belongs_to :creator, class_name: 'User', optional: true
  belongs_to :collaborator, polymorphic: true, optional: true
  belongs_to :blocked_by, class_name: 'User', foreign_key: 'blocked_by_id', optional: true
  has_many :ratings, as: :rateable, dependent: :destroy
  has_many :bookings, dependent: :destroy
  has_many :likes, as: :likeable, dependent: :destroy
  has_many :event_interests, dependent: :destroy
  has_many :event_reports, dependent: :destroy
  has_many :event_artists, dependent: :destroy
  has_many :artists, through: :event_artists, source: :artist
  has_many :event_posts, dependent: :destroy
  has_many :live_streams, dependent: :nullify
  has_many :moments, dependent: :nullify
  has_many :event_boosts, dependent: :destroy
  has_many :event_menus, dependent: :destroy
  has_many :food_bar_orders, dependent: :destroy
  has_many :waiter_calls, dependent: :destroy
  has_many :vibe_checks, dependent: :destroy
  has_many :booked_users, through: :bookings, source: :user
  has_many :liked_by_users, through: :likes, source: :user
  has_many :interested_users, through: :event_interests, source: :user
  
  # Multiple categories support (like artists)
  has_many :event_categories, dependent: :destroy
  has_many :categories, through: :event_categories

  # Event tags (country-wise / default / trending labels)
  has_many :event_taggings, dependent: :destroy
  has_many :event_tags, through: :event_taggings
  
  # Custom categories (event-specific categories with name and description)
  has_many :event_custom_categories, dependent: :destroy
  has_many :event_ticket_types, dependent: :destroy

  MAX_TICKET_TYPES = 10

  # Active Storage for photos (file uploads)
  has_many_attached :photos
  
  # Active Storage for poster/cover image
  has_one_attached :poster
  
  # Validations
  validates :title, presence: true, length: { maximum: 255 }
  validates :starts_at, presence: true
  validates :ends_at, presence: true
  validates :timezone, presence: true
  validates :status, presence: true, inclusion: { in: %w[draft published canceled completed] }
  validates :visibility, presence: true, inclusion: { in: %w[public private unlisted] }
  validates :age_restriction, numericality: { 
    only_integer: true, 
    greater_than_or_equal_to: 0, 
    less_than_or_equal_to: 99 
  }, allow_nil: true
  validates :smoking, inclusion: { 
    in: ['yes', 'no', '2 zones', 'private zone'] 
  }, allow_nil: true
  validates :block_scope, inclusion: { 
    in: %w[sales visibility checkin all] 
  }, allow_nil: true
  validates :attendance_mode, inclusion: { in: %w[rsvp tickets] }, allow_blank: true
  validates :pr_commission_type, inclusion: { in: %w[exclusive non_exclusive] }, allow_blank: true
  validates :invite_sharing, inclusion: { in: %w[creator_only creator_and_guests] }
  validates :latitude, numericality: { 
    greater_than_or_equal_to: -90, 
    less_than_or_equal_to: 90 
  }, allow_nil: true
  validates :longitude, numericality: { 
    greater_than_or_equal_to: -180, 
    less_than_or_equal_to: 180 
  }, allow_nil: true
  validates :adult_price, :child_price, :infant_price, :pet_price, numericality: {
    greater_than_or_equal_to: 0
  }, allow_nil: true
  validate :ends_after_starts
  validate :photos_count_limit
  validate :photo_size_limit
  validate :photo_urls_format
  validate :pricing_consistency

  before_validation :normalize_pricing_flags
  
  # Enums
  enum :status, { draft: 'draft', published: 'published', canceled: 'canceled', completed: 'completed' }, prefix: true
  enum :visibility, { public: 'public', private: 'private', unlisted: 'unlisted' }, prefix: true
  
  # Scopes
  scope :published, -> { where(status: 'published') }
  scope :draft, -> { where(status: 'draft') }
  scope :upcoming, -> { where('starts_at > ?', Time.current) }
  scope :past, -> { where('ends_at < ?', Time.current) }
  scope :live, -> { published.where('starts_at <= ? AND ends_at >= ?', Time.current, Time.current).where(blocked_at: nil) }
  
  # Note: Live events filtering by blocked users is handled in controllers via visible_to_user scope
  scope :by_category, ->(category) { 
    if category.is_a?(Array)
      where(category: category)
    else
      where(category: category)
    end
  }
  scope :by_categories, ->(categories) { where(category: Array(categories)) }
  scope :public_events, -> { where(visibility: 'public') }
  scope :by_venue, ->(venue_id) { where(venue_id: venue_id) }
  # Events that stored any location override (same idea as location_overridden? but includes optional fields)
  scope :with_location_override, -> {
    where(
      'events.address1 IS NOT NULL OR events.address2 IS NOT NULL OR events.city IS NOT NULL OR ' \
      'events.region IS NOT NULL OR events.postal_code IS NOT NULL OR events.country IS NOT NULL OR ' \
      'events.latitude IS NOT NULL OR events.longitude IS NOT NULL'
    )
  }
  scope :free, -> { where(is_free: true) }
  scope :paid, -> { where(is_free: false) }

  # Attendance mode: rsvp (Live + Map) | tickets (Close N hours before event)
  ATTENDANCE_MODES = %w[rsvp tickets].freeze
  # Business-side fee: exclusive (2%) | non_exclusive (5%) - charged to venue/brand/artist
  PR_COMMISSION_TYPES = %w[exclusive non_exclusive].freeze
  PR_COMMISSION_PERCENTAGES = { 'exclusive' => 2, 'non_exclusive' => 5 }.freeze

  def pr_commission_percentage
    return nil unless pr_commission_type.present?
    PR_COMMISSION_PERCENTAGES[pr_commission_type]
  end

  def tickets_mode?
    attendance_mode == 'tickets'
  end

  def tickets_closed?
    return false unless tickets_mode? && starts_at.present?
    Time.current <= (starts_at - 24.hours)
  end

  # Venue can turn off RSVP for all events at this venue until each event ends.
  def venue_rsvp_enabled?
    venue.nil? || venue.rsvp_enabled != false
  end

  def rsvp_changes_allowed?
    return false if ends_at.present? && Time.current >= ends_at

    venue_rsvp_enabled?
  end

  def ticket_sales_open?
    return nil unless tickets_mode?

    !tickets_closed?
  end

  # Replaces all ticket tiers (max MAX_TICKET_TYPES). Used by PUT /ticket_types and event create/update.
  # Raises ActiveRecord::RecordInvalid if business rules fail or child records invalid.
  def replace_ticket_types!(rows)
    raise ArgumentError, 'ticket_types must be an array' unless rows.is_a?(Array)

    rows = normalize_ticket_type_rows_for_replace(rows)

    if rows.size > MAX_TICKET_TYPES
      errors.add(:base, "Maximum #{MAX_TICKET_TYPES} ticket types per event")
      raise ActiveRecord::RecordInvalid, self
    end

    if event_ticket_types.any? { |t| t.quantity_sold > 0 }
      errors.add(:base, 'Cannot replace ticket types after tickets have been sold. Edit quantities in the future.')
      raise ActiveRecord::RecordInvalid, self
    end

    currency = self.currency || 'EUR'
    ApplicationRecord.transaction do
      event_ticket_types.destroy_all
      rows.each_with_index do |row, idx|
        row = row.permit(:name, :price, :quantity_total, :display_order) if row.respond_to?(:permit)
        row = row.to_unsafe_h if row.respond_to?(:to_unsafe_h)
        row = row.stringify_keys
        name = row['name']
        price = row['price'].to_d
        qty = row['quantity_total'].to_i
        order = (row['display_order'].presence || idx).to_i

        event_ticket_types.create!(
          name: name.to_s.strip,
          price: price,
          currency: currency,
          quantity_total: qty,
          quantity_sold: 0,
          display_order: order
        )
      end
    end
    true
  end

  # Distance filtering scope using Haversine formula
  # Returns events within min_distance and max_distance (in km) from given lat/lng
  scope :within_distance, ->(latitude, longitude, min_distance_km: nil, max_distance_km: nil) {
    return all if latitude.blank? || longitude.blank?
    
    lat = latitude.to_f
    lng = longitude.to_f
    
    # Haversine formula for distance calculation (in kilometers)
    # Using COALESCE to handle events with location override or venue location
    # Build the calculation as a single SQL expression
    distance_calc = "(6371 * acos(LEAST(1.0, cos(radians(#{lat})) * cos(radians(COALESCE(events.latitude, venues.latitude))) * cos(radians(COALESCE(events.longitude, venues.longitude)) - radians(#{lng})) + sin(radians(#{lat})) * sin(radians(COALESCE(events.latitude, venues.latitude))))))"
    
    # Join with venues to access venue coordinates
    query = joins(:venue)
            .where(
              '(events.latitude IS NOT NULL AND events.longitude IS NOT NULL) OR ' \
              '(venues.latitude IS NOT NULL AND venues.longitude IS NOT NULL)'
            )
    
    # Apply min distance filter
    if min_distance_km.present? && min_distance_km.to_f > 0
      query = query.where("#{distance_calc} >= ?", min_distance_km.to_f)
    end
    
    # Apply max distance filter
    if max_distance_km.present? && max_distance_km.to_f > 0
      query = query.where("#{distance_calc} <= ?", max_distance_km.to_f)
    end
    
    query
  }
  
  # Filter by multiple category IDs (new category system)
  scope :by_category_ids, ->(category_ids) {
    return all if category_ids.blank?
    ids = Array(category_ids).map(&:to_s).reject(&:blank?)
    return all if ids.empty?
    
    joins(:event_categories)
      .where(event_categories: { category_id: ids })
      .distinct
  }
  
  # Filter by category slugs (new category system)
  scope :by_category_slugs, ->(slugs) {
    return all if slugs.blank?
    slug_array = Array(slugs).map(&:to_s).reject(&:blank?)
    return all if slug_array.empty?
    
    joins(categories: :categories_group)
      .where(categories: { slug: slug_array })
      .distinct
  }
  
  # Filter out events created by blocked users
  scope :excluding_blocked_users, ->(user) {
    return all unless user.present?
    blocked_ids = user.blocked_users_ids
    return all if blocked_ids.empty?
    joins(:venue).where.not(venues: { owner_id: blocked_ids })
  }
  
  # Filter out events where the user is blocked by the event creator
  scope :visible_to_user, ->(user) {
    return all unless user.present?
    excluding_blocked_users(user)
  }
  
  # Common event categories
  CATEGORIES = [
    'Adventures',
    'Activities',
    'Party Events',
    'Bars',
    'Social',
    'Sports',
    'Festivals',
    'Poker & GMBH',
    'Rock & Billiards',
    'Standup Comedy',
    'Social Meetups',
    'Escape rooms',
    'Arts',
    'Theater',
    'Real estate',
    'Gaming',
    'Networking & Business EXPOs'
  ].freeze
  
  # Methods
  def is_live?
    status_published? && 
    Time.current.between?(starts_at, ends_at) && 
    blocked_at.nil?
  end
  
  def is_upcoming?
    starts_at > Time.current
  end
  
  def is_past?
    ends_at < Time.current
  end

  def free?
    is_free?
  end

  def age_pricing_enabled?
    [adult_price, child_price, infant_price, pet_price].any? { |value| !value.nil? }
  end

  def age_pricing_positive?
    [adult_price, child_price, infant_price, pet_price].compact.any? { |value| value.to_f > 0 }
  end

  def any_pricing_positive?
    age_pricing_positive? ||
      (price.present? && price.to_f > 0) ||
      (pre_booking_price.present? && pre_booking_price.to_f > 0)
  end
  
  def duration_minutes
    return 0 if starts_at.nil? || ends_at.nil?
    ((ends_at - starts_at) / 60).to_i
  end
  
  def duration_hours
    (duration_minutes / 60.0).round(1)
  end
  
  def publish!
    update!(
      status: 'published',
      published_at: Time.current
    )
  end
  
  def cancel!
    update!(status: 'canceled')
  end
  
  def block!(user, scope: 'all', reason: nil)
    self.blocked_at = Time.current
    self.blocked_by = user
    self.block_scope = scope
    self.block_reason = reason
  end
  
  def unblock!
    self.blocked_at = nil
    self.blocked_by = nil
    self.block_scope = nil
    self.block_reason = nil
    save!
  end
  
  def bookings_count
    bookings.confirmed.count
  end
  
  def likes_count
    likes.count
  end
  
  # Simple interests count (no RSVP status)
  def interests_count
    event_interests.where(rsvp_status: nil).count
  end
  
  # RSVPs count (with status yes/no/maybe)
  def rsvps_count
    event_interests.where.not(rsvp_status: nil).count
  end
  
  def user_booked?(user)
    bookings.exists?(user: user, status: 'confirmed')
  end
  
  def user_liked?(user)
    likes.exists?(user: user)
  end
  
  # Check if user has simple interest (no RSVP status)
  def user_interested?(user)
    event_interests.exists?(user: user, rsvp_status: nil)
  end
  
  # Check if user has RSVP (with status)
  def user_has_rsvp?(user)
    event_interests.exists?(user: user, rsvp_status: ['yes', 'no', 'maybe'])
  end
  
  def user_rsvp_status(user)
    rsvp = event_interests.find_by(user: user, rsvp_status: ['yes', 'no', 'maybe'])
    rsvp&.rsvp_status
  end
  
  def rsvp_yes_count
    event_interests.attending.sum { |i| i.total_attendees || 1 }
  end
  
  def rsvp_no_count
    event_interests.not_attending.count
  end
  
  def rsvp_maybe_count
    event_interests.maybe_attending.count
  end
  
  def rsvp_count
    rsvp_yes_count + rsvp_no_count + rsvp_maybe_count
  end
  
  def reports_count
    event_reports.pending.count
  end
  
  def user_reported?(user)
    event_reports.exists?(reporter: user)
  end
  
  # Category methods (supports both legacy single category and new multiple categories)
  def belongs_to_category?(category_name)
    # Check new multiple categories first
    if event_categories.any?
      categories.joins(:categories_group)
                .where(categories_groups: { slug: 'event-categories' })
                .exists?(slug: category_name.to_s)
    else
      # Fall back to legacy single category
      category.present? && category == category_name.to_s
    end
  end
  
  def belongs_to_any_category?(*category_names)
    category_names.any? { |cat| belongs_to_category?(cat) }
  end
  
  def valid_category?
    category.present? && CATEGORIES.include?(category)
  end
  
  # Multiple categories management (like artists)
  def category_ids
    event_categories.pluck(:category_id)
  end
  
  def category_slugs
    categories.pluck(:slug)
  end
  
  def all_categories
    # Return both legacy category and new multiple categories
    result = []
    if category.present?
      # Try to find Category record by slug to get ID
      category_record = Category.joins(:categories_group)
                                .where(categories_groups: { slug: 'event-categories' })
                                .find_by(slug: category)
      
      legacy_cat = { 
        name: category, 
        slug: category, 
        source: 'legacy' 
      }
      legacy_cat[:id] = category_record.id if category_record
      result << legacy_cat
    end
    event_categories.includes(:category).each do |ec|
      result << { 
        id: ec.category_id, 
        name: ec.category.name, 
        slug: ec.category.slug, 
        source: ec.source 
      }
    end
    result.uniq { |c| c[:slug] }
  end
  
  def add_category(category_id, source: 'manual')
    return false if event_categories.exists?(category_id: category_id)
    event_categories.create(category_id: category_id, source: source)
  end
  
  def remove_category(category_id)
    event_categories.find_by(category_id: category_id)&.destroy
  end
  
  def replace_categories(category_ids, source: 'manual')
    transaction do
      event_categories.destroy_all
      category_ids.each do |cat_id|
        event_categories.create!(category_id: cat_id, source: source)
      end
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end
  
  def artists_count
    event_artists.confirmed.count
  end
  
  def confirmed_artists
    event_artists.confirmed.ordered
  end
  
  def live_artists
    event_artists.live
  end
  
  def posts_count
    event_posts.active.count
  end
  
  def recent_posts(limit = 10)
    event_posts.active.recent.limit(limit)
  end
  
  # Menu/Ordering methods
  def has_active_menus?
    event_menus.active.any?
  end
  
  def food_menu_available?
    event_menus.active.food_menus.any? { |m| m.available_now? }
  end
  
  def bar_menu_available?
    event_menus.active.bar_menus.any? { |m| m.available_now? }
  end
  
  # VibeCheck methods
  def vibe_check_rating
    vibe_checks.published.average(:overall_rating)&.round(1)
  end
  
  def vibe_checks_count
    vibe_checks.published.count
  end
  
  def update_vibe_check_stats!
    # Can be used to cache stats if needed
    # For now, stats are calculated on-demand
    true
  end
  
  # Review methods (using Rating model)
  def approved_reviews
    ratings.approved
  end
  
  def average_rating
    approved_reviews.average(:rating)&.round(2) || 0.0
  end
  
  def reviews_count
    approved_reviews.count
  end
  
  def user_review(user)
    ratings.find_by(user: user)
  end
  
  def can_submit_vibe_check?(user)
    # Can only submit after event is over
    return false unless is_past?
    
    # Must have attended (booked and checked in, or just booked for virtual events)
    booking = bookings.find_by(user: user)
    return false unless booking
    
    # Already submitted
    return false if vibe_checks.exists?(user: user)
    
    true
  end
  
  # Menu methods
  def has_menu?
    event_menus.active.exists?
  end
  
  def has_food_menu?
    event_menus.active.food_menus.exists?
  end
  
  def has_bar_menu?
    event_menus.active.bar_menus.exists?
  end
  
  def active_menu
    event_menus.active.available_now.first
  end
  
  # Location override methods
  def location_overridden?
    address1.present? || city.present? || latitude.present? || longitude.present?
  end
  
  def event_address
    if location_overridden?
      {
        address1: address1,
        address2: address2,
        city: city,
        region: region,
        postal_code: postal_code,
        country: country,
        full_address: full_address
      }
    else
      if venue
        {
          address1: venue.address1,
          address2: venue.address2,
          city: venue.city,
          region: venue.region,
          postal_code: venue.postal_code,
          country: venue.country,
          full_address: venue.full_address
        }
      else
        {
          address1: nil,
          address2: nil,
          city: nil,
          region: nil,
          postal_code: nil,
          country: nil,
          full_address: nil
        }
      end
    end
  end
  
  def event_location
    if latitude.present? && longitude.present?
      {
        latitude: latitude.to_f,
        longitude: longitude.to_f
      }
    elsif venue&.coordinates?
      {
        latitude: venue.latitude.to_f,
        longitude: venue.longitude.to_f
      }
    else
      nil
    end
  end
  
  def event_city
    city.presence || venue&.city
  end
  
  def event_country
    country.presence || venue&.country
  end
  
  def full_address
    if location_overridden?
      parts = [address1, address2, city, region, postal_code, country].compact
      parts.join(', ')
    else
      venue&.full_address
    end
  end
  
  def coordinates?
    (latitude.present? && longitude.present?) || venue&.coordinates?
  end
  
  # Private event pricing methods
  def pre_booking_active?
    # If no deadline set, pre-booking is always active (as long as price is set)
    return true if pre_booking_deadline.nil? && pre_booking_price.present? && pre_booking_price.to_f > 0
    # If deadline exists, check if we're within it
    return false if pre_booking_deadline.nil?
    Time.current <= pre_booking_deadline
  end
  
  def current_price
    if pre_booking_active? && pre_booking_price.present?
      pre_booking_price
    else
      display_price
    end
  end
  
  # Returns the price to display in event listings/details.
  # Falls back to adult_price when flat price is nil/zero but age pricing exists.
  def display_price
    return price if price.present? && price.to_f > 0
    
    # If flat price is nil/zero but age pricing exists, use adult_price as display price
    if age_pricing_enabled? && adult_price.present? && adult_price.to_f > 0
      return adult_price
    end
    
    price || 0.0
  end
  
  def has_pre_booking?
    pre_booking_price.present? && pre_booking_price.to_f > 0
  end
  
  # Private event access methods
  def can_user_access?(user)
    return true if visibility_public?
    return false if user.nil?
    
    # Venue owner can always access
    return true if venue&.owner_id == user.id
    
    # Admin can always access
    return true if user.role_admin?
    
    # Check if user is booked or interested
    return true if user_booked?(user) || user_interested?(user)
    
    # Check if user is an artist performing at the event
    return true if artists.exists?(id: user.id)
    
    false
  end

  INVITE_SHARING_CREATOR_ONLY = 'creator_only'.freeze
  INVITE_SHARING_CREATOR_AND_GUESTS = 'creator_and_guests'.freeze

  def invite_sharing_creator_only?
    invite_sharing == INVITE_SHARING_CREATOR_ONLY
  end

  def invite_sharing_creator_and_guests?
    invite_sharing == INVITE_SHARING_CREATOR_AND_GUESTS
  end

  # Who may call share/invite endpoints (QR + invite link) for private/unlisted events.
  def can_share_invite?(user)
    return false if user.nil?

    return true if user.role_admin?
    return true if creator_id.present? && creator_id == user.id
    return true if venue&.owner_id == user.id

    return false if invite_sharing_creator_only?

    # creator_and_guests: booked, RSVP'd, or performing artist
    return true if user_booked?(user) || user_has_rsvp?(user)
    return true if artists.exists?(id: user.id)

    false
  end

  def ensure_invite_token!
    return invite_token if invite_token.present?

    new_token = nil
    10.times do
      candidate = SecureRandom.urlsafe_base64(24)
      next if Event.where.not(id: id).exists?(invite_token: candidate)

      new_token = candidate
      break
    end
    raise 'Could not generate invite token' if new_token.blank?

    update_column(:invite_token, new_token)
    self.invite_token = new_token
    new_token
  end

  def regenerate_invite_token!
    update_column(:invite_token, nil)
    self.invite_token = nil
    ensure_invite_token!
  end
  
  # Cancellation policy methods for booking cancellations
  def booking_cancellation_allowed?
    cancellation_policy_enabled? && cancellation_deadline_hours.present?
  end
  
  def booking_cancellation_deadline
    return nil unless booking_cancellation_allowed?
    starts_at - cancellation_deadline_hours.hours
  end
  
  def past_cancellation_deadline?
    return false unless booking_cancellation_allowed?
    Time.current >= booking_cancellation_deadline
  end
  
  def within_cancellation_window?
    booking_cancellation_allowed? && !past_cancellation_deadline?
  end
  
  def calculate_cancellation_refund(booking_price)
    return 0 if booking_price.nil? || booking_price.zero?
    
    # No cancellation policy = full refund
    return booking_price unless cancellation_policy_enabled?
    
    # Within free cancellation window = full refund
    return booking_price if within_cancellation_window?
    
    # Past deadline = apply cancellation fee
    fee_percentage = cancellation_fee_percentage || 0
    refund_percentage = 100 - fee_percentage
    (booking_price * (refund_percentage / 100.0)).round(2)
  end
  
  def calculate_cancellation_fee(booking_price)
    return 0 if booking_price.nil? || booking_price.zero?
    booking_price - calculate_cancellation_refund(booking_price)
  end
  
  # Photo methods
  # Returns all photo URLs (both uploaded files and external URLs)
  def has_photos?
    photos.attached? || (photo_urls.present? && photo_urls.is_a?(Array) && photo_urls.any?)
  end
  
  def photos_count
    attached_count = photos.attached? ? photos.count : 0
    url_count = photo_urls.is_a?(Array) ? photo_urls.length : 0
    attached_count + url_count
  end
  
  # Returns array of all photo URLs (uploaded files + external URLs)
  # This is what gets returned in API responses
  def photo_urls_array(host: nil)
    urls = []
    
    # 1. URLs from uploaded files (Active Storage)
    # When you upload files via photos[], they're stored and URLs are generated automatically
    if photos.attached?
      # Extract host from provided host URL if it's a full URL
      host_name = if host.present?
                    uri = URI.parse(host)
                    "#{uri.scheme}://#{uri.host}#{uri.port && uri.port != 80 && uri.port != 443 ? ":#{uri.port}" : ""}"
                  else
                    ENV['API_BASE_URL'] || 'https://vibesapp.digital4design.com'
                  end
      
      urls += photos.map do |photo|
        begin
          Rails.application.routes.url_helpers.rails_blob_url(photo, host: host_name)
        rescue => e
          Rails.logger.error "Error generating photo URL for event #{id}: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          nil
        end
      end.compact
    end
    
    # 2. External URLs (photo_urls JSON column)
    # For images already hosted elsewhere (S3, Cloudinary, CDN, etc.)
    if photo_urls.is_a?(Array)
      urls += photo_urls.compact
    end
    
    urls
  end
  
  # Poster/Cover image methods
  def has_poster?
    poster.attached? || poster_url.present?
  end
  
  def poster_image_url(host: nil)
    # Return uploaded poster URL if attached
    if poster.attached?
      host_name = if host.present?
                    uri = URI.parse(host)
                    "#{uri.scheme}://#{uri.host}#{uri.port && uri.port != 80 && uri.port != 443 ? ":#{uri.port}" : ""}"
                  else
                    ENV['API_BASE_URL'] || 'https://vibesapp.digital4design.com'
                  end
      begin
        Rails.application.routes.url_helpers.rails_blob_url(poster, host: host_name)
      rescue => e
        Rails.logger.error "Error generating poster URL for event #{id}: #{e.message}"
        poster_url # Fall back to URL field
      end
    else
      # Return external poster URL if set
      poster_url
    end
  end
  
  def cancellation_policy_info
    return nil unless cancellation_policy_enabled?
    
    {
      enabled: true,
      deadline_hours: cancellation_deadline_hours,
      deadline: booking_cancellation_deadline&.iso8601,
      fee_percentage: cancellation_fee_percentage&.to_f || 0,
      within_free_cancellation_window: within_cancellation_window?,
      past_deadline: past_cancellation_deadline?
    }
  end

  # Boost methods
  def active_boost
    event_boosts.active.running.first
  end

  def has_active_boost?
    event_boosts.active.running.exists?
  end

  def latest_boost
    event_boosts.order(created_at: :desc).first
  end

  def boosts_count
    event_boosts.count
  end

  def is_boosted?
    has_active_boost?
  end
  
  private

  # Expands JSON strings (multipart clients often send one blob or one string per row).
  def normalize_ticket_type_rows_for_replace(rows)
    rows.flat_map { |row| normalize_one_ticket_type_payload(row) }
  end

  def normalize_one_ticket_type_payload(row)
    return [] if row.nil?

    if row.is_a?(String)
      stripped = row.strip
      return [] if stripped.blank?
      parsed = JSON.parse(stripped)
      case parsed
      when Array then parsed
      when Hash then [parsed]
      else []
      end
    elsif row.respond_to?(:permit) || row.is_a?(Hash)
      [row]
    else
      []
    end
  rescue JSON::ParserError
    []
  end

  def normalize_pricing_flags
    if any_pricing_positive?
      self.is_free = false
    else
      self.is_free = true
    end
  end

  def pricing_consistency
    if is_free? && any_pricing_positive?
      errors.add(:is_free, 'cannot be true when prices are set')
    end
  end
  
  def ends_after_starts
    return unless starts_at.present? && ends_at.present?
    
    if ends_at <= starts_at
      errors.add(:ends_at, 'must be after start time')
    end
  end
  
  def photos_count_limit
    attached_count = photos.attached? ? photos.count : 0
    url_count = photo_urls.is_a?(Array) ? photo_urls.length : 0
    total = attached_count + url_count
    
    if total > 10
      errors.add(:base, 'cannot have more than 10 photos total (files + URLs)')
    end
  end
  
  def photo_size_limit
    return unless photos.attached?
    
    photos.each do |photo|
      if photo.byte_size > 10.megabytes
        errors.add(:photos, 'each photo file must be less than 10MB')
        break
      end
    end
  end
  
  def photo_urls_format
    return unless photo_urls.present?
    
    unless photo_urls.is_a?(Array)
      errors.add(:photo_urls, 'must be an array')
      return
    end
    
    photo_urls.each do |url|
      unless url.is_a?(String) && (url.start_with?('http://') || url.start_with?('https://'))
        errors.add(:photo_urls, 'each URL must be a valid HTTP/HTTPS URL')
        break
      end
    end
  end
end

