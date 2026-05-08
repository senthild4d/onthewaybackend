class EventCategory < ApplicationRecord
  belongs_to :event
  belongs_to :category
  
  # Validations
  validates :event_id, uniqueness: { scope: :category_id, message: 'already has this category' }
  validates :source, presence: true, inclusion: { in: %w[manual auto system] }
  
  # Scopes
  scope :manual, -> { where(source: 'manual') }
  scope :auto, -> { where(source: 'auto') }
  scope :by_event, ->(event_id) { where(event_id: event_id) }
  scope :by_category, ->(category_id) { where(category_id: category_id) }
end


