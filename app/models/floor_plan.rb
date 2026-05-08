class FloorPlan < ApplicationRecord
  belongs_to :venue
  has_many :floor_plan_zones, dependent: :destroy
  has_many :floor_plan_elements, dependent: :destroy
  has_many :tables, through: :floor_plan_zones
  
  # Validations
  validates :name, presence: true, length: { maximum: 255 }
  validates :venue_type, presence: true, inclusion: { 
    in: %w[restaurant pub bar casino gaming sports club lounge cafe other] 
  }
  validates :width, :height, presence: true, numericality: { greater_than: 0 }
  validates :scale_factor, numericality: { greater_than: 0 }, allow_nil: true
  validates :status, presence: true, inclusion: { in: %w[draft active archived] }
  
  # Enums
  enum :status, { draft: 'draft', active: 'active', archived: 'archived' }, prefix: true
  enum :venue_type, {
    restaurant: 'restaurant',
    pub: 'pub',
    bar: 'bar',
    casino: 'casino',
    gaming: 'gaming',
    sports: 'sports',
    club: 'club',
    lounge: 'lounge',
    cafe: 'cafe',
    other: 'other'
  }, prefix: true
  
  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :default_plans, -> { where(is_default: true) }
  scope :by_venue_type, ->(type) { where(venue_type: type) }
  
  # Callbacks
  before_save :ensure_single_default, if: :is_default?
  
  # Methods
  def total_capacity
    floor_plan_zones.sum(:capacity) || tables.sum(:max_capacity)
  end
  
  def total_tables
    tables.count
  end
  
  def total_seats
    tables.joins(:seats).count
  end
  
  def bookable_tables_count
    tables.where(is_bookable: true, is_active: true).count
  end
  
  def available_zones
    floor_plan_zones.where(is_active: true)
  end
  
  def to_canvas_json
    {
      id: id,
      name: name,
      width: width,
      height: height,
      scale_factor: scale_factor,
      settings: settings,
      zones: floor_plan_zones.map(&:to_canvas_json),
      elements: floor_plan_elements.order(:display_order).map(&:to_canvas_json),
      tables: tables.includes(:seats).map(&:to_canvas_json)
    }
  end
  
  private
  
  def ensure_single_default
    return unless is_default_changed? && is_default?
    
    FloorPlan.where(venue_id: venue_id, is_default: true)
              .where.not(id: id)
              .update_all(is_default: false)
  end
end

