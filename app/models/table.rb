class Table < ApplicationRecord
  belongs_to :floor_plan_zone
  has_many :seats, dependent: :destroy
  has_one :floor_plan, through: :floor_plan_zone
  
  # Validations
  validates :table_number, presence: true, length: { maximum: 50 }
  validates :table_number, uniqueness: { scope: :floor_plan_zone_id }
  validates :table_type, presence: true, inclusion: {
    in: %w[standard booth bar_stool highchair vip counter standing gaming other]
  }
  validates :shape, presence: true, inclusion: {
    in: %w[rectangle circle square oval custom]
  }
  validates :x_position, :y_position, :width, :height, presence: true
  validates :min_capacity, :max_capacity, presence: true, numericality: { greater_than: 0 }
  validate :max_capacity_greater_than_min
  
  # Enums
  enum :table_type, {
    standard: 'standard',
    booth: 'booth',
    bar_stool: 'bar_stool',
    highchair: 'highchair',
    vip: 'vip',
    counter: 'counter',
    standing: 'standing',
    gaming: 'gaming',
    other: 'other'
  }, prefix: true
  
  enum :shape, {
    rectangle: 'rectangle',
    circle: 'circle',
    square: 'square',
    oval: 'oval',
    custom: 'custom'
  }, prefix: true
  
  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :bookable, -> { where(is_bookable: true, is_active: true) }
  scope :accessible, -> { where(is_accessible: true) }
  scope :by_type, ->(type) { where(table_type: type) }
  scope :by_capacity, ->(min, max) { where('max_capacity >= ? AND min_capacity <= ?', min, min) }
  
  # Methods
  def total_seats
    seats.count
  end
  
  def available_seats
    seats.where(is_active: true)
  end
  
  def full_name
    table_name.present? ? "#{table_number} - #{table_name}" : table_number
  end
  
  def to_canvas_json
    {
      id: id,
      table_number: table_number,
      table_name: table_name,
      table_type: table_type,
      shape: shape,
      position: {
        x: x_position,
        y: y_position
      },
      dimensions: {
        width: width,
        height: height
      },
      rotation: rotation,
      capacity: {
        min: min_capacity,
        max: max_capacity
      },
      is_accessible: is_accessible,
      is_active: is_active,
      is_bookable: is_bookable,
      color: color,
      custom_properties: custom_properties,
      seats: seats.map(&:to_canvas_json)
    }
  end
  
  private
  
  def max_capacity_greater_than_min
    return unless min_capacity && max_capacity
    
    if max_capacity < min_capacity
      errors.add(:max_capacity, 'must be greater than or equal to minimum capacity')
    end
  end
end

