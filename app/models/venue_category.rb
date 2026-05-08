class VenueCategory < ApplicationRecord
  belongs_to :venue
  belongs_to :category
  
  # Validations
  validates :venue_id, uniqueness: { scope: :category_id, message: 'already has this category' }
  validates :source, presence: true, inclusion: { in: %w[manual auto system] }
  
  # Scopes
  scope :manual, -> { where(source: 'manual') }
  scope :auto, -> { where(source: 'auto') }
  scope :by_venue, ->(venue_id) { where(venue_id: venue_id) }
  scope :by_category, ->(category_id) { where(category_id: category_id) }
end
