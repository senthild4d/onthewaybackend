class FloorPlanElement < ApplicationRecord
  belongs_to :floor_plan
  
  # Validations
  validates :element_type, presence: true, inclusion: {
    in: %w[wall door window pillar decor bar stage entrance exit restroom kitchen other]
  }
  validates :geometry, presence: true
  validates :display_order, numericality: { greater_than_or_equal_to: 0 }
  
  # Enums
  enum :element_type, {
    wall: 'wall',
    door: 'door',
    window: 'window',
    pillar: 'pillar',
    decor: 'decor',
    bar: 'bar',
    stage: 'stage',
    entrance: 'entrance',
    exit: 'exit',
    restroom: 'restroom',
    kitchen: 'kitchen',
    other: 'other'
  }, prefix: true
  
  # Scopes
  scope :visible, -> { where(is_visible: true) }
  scope :by_type, ->(type) { where(element_type: type) }
  scope :ordered, -> { order(:display_order) }
  
  # Methods
  def to_canvas_json
    {
      id: id,
      element_type: element_type,
      name: name,
      geometry: geometry,
      color: color,
      rotation: rotation,
      properties: properties,
      is_visible: is_visible,
      display_order: display_order
    }
  end
end

