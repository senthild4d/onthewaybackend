class EventCustomCategory < ApplicationRecord
  belongs_to :event

  # Validations
  validates :name, presence: true, length: { maximum: 255 }
  validates :name, uniqueness: { scope: :event_id, message: "Custom category name must be unique per event" }
  
  # Scopes
  scope :ordered, -> { order(name: :asc) }
end

