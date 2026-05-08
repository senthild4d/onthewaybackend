class Venue < ApplicationRecord
  belongs_to :owner, class_name: 'User', foreign_key: 'owner_id'
  has_many :events, dependent: :destroy
  has_many :venue_staff, dependent: :destroy
  has_many :staff_users, through: :venue_staff, source: :user
  has_many :venue_blocklists, dependent: :destroy
  has_many :blocked_users, through: :venue_blocklists, source: :user
  has_many :ratings, as: :rateable, dependent: :destroy
  has_many :approved_ratings, -> { approved }, as: :rateable, class_name: 'Rating'
  has_many :likes, as: :likeable, dependent: :destroy
  has_many :liked_by_users, through: :likes, source: :user
  has_many :venue_interests, dependent: :destroy
  has_many :interested_users, through: :venue_interests, source: :user
  has_many :venue_follows, dependent: :destroy
  has_many :followers, through: :venue_follows, source: :user
  has_many :venue_pr_partnerships, dependent: :destroy
  has_many :pr_users, through: :venue_pr_partnerships, source: :user
  has_one :master_pr_partnership, -> { active_master }, class_name: 'VenuePrPartnership'
  has_one :master_pr_user, through: :master_pr_partnership, source: :user
  has_many :junior_pr_partnerships, -> { active_junior }, class_name: 'VenuePrPartnership'
  has_many :junior_pr_users, through: :junior_pr_partnerships, source: :user
  has_many :active_pr_partnerships, -> { active }, class_name: 'VenuePrPartnership'
  has_many :venue_menus, dependent: :destroy
  has_many :floor_plans, dependent: :destroy
  has_many :live_streams, dependent: :destroy
  has_one :active_floor_plan, -> { where(status: 'active', is_default: true) }, class_name: 'FloorPlan'
  
  # Categories support (like events)
  has_many :venue_categories, dependent: :destroy
  has_many :categories, through: :venue_categories
  
  # Active Storage for venue image
  has_one_attached :image
  
  # Validations
  validates :name, presence: true, length: { maximum: 255 }
  validates :city, presence: true, length: { maximum: 100 }
  validates :country, presence: true, length: { maximum: 100 }
  validates :contact_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  # Allow international contact phone numbers with flexible length (just digits + optional leading +)
  validates :contact_phone, format: { with: /\A\+?\d+\z/, message: "must contain only digits (and optional leading +)" }, allow_nil: true
  validates :capacity, numericality: { greater_than: 0 }, allow_nil: true
  validates :status, presence: true, inclusion: { in: %w[active inactive] }
  validates :latitude, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }, allow_nil: true
  validates :longitude, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }, allow_nil: true
  validates :default_currency, length: { maximum: 10 }, allow_nil: true
  
  # Enums
  enum :status, { active: 'active', inactive: 'inactive' }, prefix: true
  
  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :inactive, -> { where(status: 'inactive') }
  scope :by_city, ->(city) { where(city: city) }
  scope :by_country, ->(country) { where(country: country) }
  
  # Default currency for events created at this venue (e.g. USD, EUR, GBP)
  def effective_default_currency
    default_currency.presence || 'USD'
  end
  
  # Methods
  def full_address
    parts = [address1, address2, city, region, postal_code, country].compact
    parts.join(', ')
  end
  
  def coordinates?
    latitude.present? && longitude.present?
  end
  
  def average_rating
    approved_ratings.average(:rating)&.round(2) || 0.0
  end
  
  def ratings_count
    approved_ratings.count
  end
  
  def user_rating(user)
    ratings.find_by(user: user)
  end
  
  def likes_count
    likes.count
  end
  
  def user_liked?(user)
    likes.exists?(user: user)
  end
  
  def interests_count
    venue_interests.count
  end
  
  def user_interested?(user)
    venue_interests.exists?(user: user)
  end
  
  def user_rsvp_status(user)
    interest = venue_interests.find_by(user: user)
    interest&.rsvp_status
  end
  
  def rsvp_yes_count
    venue_interests.attending.sum { |i| i.total_attendees }
  end
  
  def rsvp_no_count
    venue_interests.not_attending.count
  end
  
  def rsvp_maybe_count
    venue_interests.maybe_attending.count
  end
  
  # Following methods
  def followers_count
    followers.count
  end

  def events_count
    events.count
  end

  def user_following?(user)
    venue_follows.exists?(user: user)
  end
  
  # Blocklist methods
  def user_blocked?(user)
    venue_blocklists.active.exists?(user: user)
  end
  
  def block_user!(user, blocked_by:, reason:, **options)
    venue_blocklists.create!(
      user: user,
      blocked_by: blocked_by,
      reason: reason,
      description: options[:description],
      incident_type: options[:incident_type],
      related_event_id: options[:related_event_id],
      related_booking_id: options[:related_booking_id],
      is_permanent: options[:is_permanent] || false,
      blocked_until: options[:blocked_until]
    )
  end
  
  def unblock_user!(user)
    venue_blocklists.where(user: user).destroy_all
  end
  
  # Floor plan methods
  def has_floor_plan?
    floor_plans.exists?
  end
  
  def default_floor_plan
    floor_plans.find_by(is_default: true) || floor_plans.active.first
  end
  
  def total_table_capacity
    active_floor_plan&.total_capacity || capacity
  end
  
  # VibeCheck rate - average rating from all vibe checks for events at this venue
  def vibecheck_rate
    # Get all vibe checks from events at this venue that are published
    venue_vibe_checks = VibeCheck.joins(:event)
                                  .where(events: { venue_id: id })
                                  .published
    
    return nil if venue_vibe_checks.empty?
    
    # Calculate average of overall_rating
    venue_vibe_checks.average(:overall_rating)&.round(1)
  end
  
  # Check if venue has an image attached
  def has_image?
    image.attached?
  end
  
  # Get image URL
  def image_url(host: nil)
    return nil unless image.attached?
    
    host_name = if host.present?
                  uri = URI.parse(host)
                  "#{uri.scheme}://#{uri.host}#{uri.port && uri.port != 80 && uri.port != 443 ? ":#{uri.port}" : ""}"
                else
                  ENV['API_BASE_URL'] || 'https://vibesapp.digital4design.com'
                end
    
    begin
      Rails.application.routes.url_helpers.rails_blob_url(image, host: host_name)
    rescue => e
      Rails.logger.error "Error generating image URL for venue #{id}: #{e.message}"
      nil
    end
  end

  # Category management methods
  def all_categories
    venue_categories.includes(:category).map do |vc|
      {
        id: vc.category_id,
        name: vc.category.name,
        slug: vc.category.slug,
        icon_key: vc.category.icon_key,
        source: vc.source
      }
    end
  end

  def category_ids
    venue_categories.pluck(:category_id)
  end

  def add_category(category_id, source: 'manual')
    return false if venue_categories.exists?(category_id: category_id)
    venue_categories.create(category_id: category_id, source: source)
  end

  def remove_category(category_id)
    venue_categories.find_by(category_id: category_id)&.destroy
  end

  def replace_categories(category_ids, source: 'manual')
    transaction do
      venue_categories.destroy_all
      category_ids.each do |cat_id|
        venue_categories.create!(category_id: cat_id, source: source)
      end
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def belongs_to_category?(category_name)
    categories.exists?(slug: category_name.to_s.downcase)
  end

  def belongs_to_any_category?(*category_names)
    category_names.any? { |cat| belongs_to_category?(cat) }
  end
end

