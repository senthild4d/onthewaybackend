class Seat < ApplicationRecord
  belongs_to :table
  
  # Validations
  validates :seat_number, presence: true, numericality: { greater_than: 0 }
  validates :seat_number, uniqueness: { scope: :table_id }
  validates :x_position, :y_position, presence: true
  validates :seat_type, presence: true, inclusion: {
    in: %w[standard highchair wheelchair bar_stool bench other]
  }
  
  # Enums
  enum :seat_type, {
    standard: 'standard',
    highchair: 'highchair',
    wheelchair: 'wheelchair',
    bar_stool: 'bar_stool',
    bench: 'bench',
    other: 'other'
  }, prefix: true
  
  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :accessible, -> { where(is_accessible: true) }
  scope :by_type, ->(type) { where(seat_type: type) }
  scope :ordered, -> { order(:seat_number) }
  
  # Methods
  def to_canvas_json
    {
      id: id,
      seat_number: seat_number,
      position: {
        x: x_position,
        y: y_position
      },
      position_label: position_label,
      seat_type: seat_type,
      is_active: is_active,
      is_accessible: is_accessible
    }
  end
end

