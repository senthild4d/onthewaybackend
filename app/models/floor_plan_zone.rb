class FloorPlanZone < ApplicationRecord
  belongs_to :floor_plan
  has_many :tables, foreign_key: :floor_plan_zone_id, dependent: :destroy
  
  # Validations
  validates :name, presence: true, length: { maximum: 255 }
  validates :zone_type, presence: true, inclusion: {
    in: %w[dining bar vip outdoor stage dance_floor gaming other]
  }
  validates :geometry, presence: true
  validates :capacity, numericality: { greater_than: 0 }, allow_nil: true
  validates :min_spend, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :display_order, numericality: { greater_than_or_equal_to: 0 }
  
  # Enums
  enum :zone_type, {
    dining: 'dining',
    bar: 'bar',
    vip: 'vip',
    outdoor: 'outdoor',
    stage: 'stage',
    dance_floor: 'dance_floor',
    gaming: 'gaming',
    other: 'other'
  }, prefix: true
  
  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :bookable, -> { where(is_bookable: true) }
  scope :by_type, ->(type) { where(zone_type: type) }
  scope :ordered, -> { order(:display_order) }
  
  # Methods
  def total_tables
    tables.count
  end
  
  def available_tables
    tables.where(is_active: true, is_bookable: true)
  end
  
  def total_capacity_from_tables
    tables.sum(:max_capacity)
  end
  
  def to_canvas_json
    {
      id: id,
      name: name,
      zone_type: zone_type,
      geometry: geometry,
      color: color,
      capacity: capacity,
      is_bookable: is_bookable,
      is_active: is_active,
      min_spend: min_spend,
      display_order: display_order
    }
  end
end

