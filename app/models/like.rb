class Like < ApplicationRecord
  belongs_to :user
  belongs_to :likeable, polymorphic: true
  
  # Validations
  validates :user_id, uniqueness: { 
    scope: [:likeable_type, :likeable_id], 
    message: "has already liked this item" 
  }
  validates :likeable_type, inclusion: { in: %w[Event Venue] }
end

