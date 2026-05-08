class Rating < ApplicationRecord
  belongs_to :user
  belongs_to :rateable, polymorphic: true
  
  # Validations
  validates :rating, presence: true, numericality: { 
    only_integer: true, 
    greater_than_or_equal_to: 1, 
    less_than_or_equal_to: 5 
  }
  validates :user_id, uniqueness: { 
    scope: [:rateable_type, :rateable_id], 
    message: "has already rated this item" 
  }
  validates :moderation_status, presence: true, inclusion: { in: %w[pending approved rejected] }
  
  # Enums
  enum :moderation_status, { pending: 'pending', approved: 'approved', rejected: 'rejected' }, prefix: true
  
  # Scopes
  scope :approved, -> { where(moderation_status: 'approved') }
  scope :pending, -> { where(moderation_status: 'pending') }
  scope :rejected, -> { where(moderation_status: 'rejected') }
  scope :published, -> { where.not(published_at: nil) }
  
  # Callbacks
  before_save :set_published_at, if: :will_save_change_to_moderation_status?
  
  private
  
  def set_published_at
    if moderation_status_approved? && published_at.nil?
      self.published_at = Time.current
    elsif !moderation_status_approved?
      self.published_at = nil
    end
  end
end

