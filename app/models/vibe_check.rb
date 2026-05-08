class VibeCheck < ApplicationRecord
  belongs_to :event
  belongs_to :user
  belongs_to :booking, optional: true
  
  validates :overall_rating, presence: true, inclusion: { in: 1..5 }
  validates :atmosphere_rating, :music_rating, :crowd_rating, :service_rating, :value_rating,
            inclusion: { in: 1..5 }, allow_nil: true
  validates :user_id, uniqueness: { scope: :event_id, message: 'has already reviewed this event' }
  validates :status, presence: true, inclusion: { in: %w[published hidden flagged] }
  
  enum :status, {
    published: 'published',
    hidden: 'hidden',
    flagged: 'flagged'
  }, prefix: true
  
  scope :published, -> { where(status: 'published') }
  scope :recent, -> { order(created_at: :desc) }
  scope :high_rated, -> { where('overall_rating >= ?', 4) }
  scope :low_rated, -> { where('overall_rating <= ?', 2) }
  scope :would_recommend, -> { where(would_recommend: true) }
  
  after_create :update_event_stats
  after_update :update_event_stats
  
  def average_category_rating
    ratings = [atmosphere_rating, music_rating, crowd_rating, service_rating, value_rating].compact
    return nil if ratings.empty?
    (ratings.sum.to_f / ratings.size).round(1)
  end
  
  def positive?
    overall_rating >= 4
  end
  
  def negative?
    overall_rating <= 2
  end
  
  def increment_helpful!
    increment!(:helpful_count)
  end
  
  private
  
  def update_event_stats
    # Recalculate event average rating
    event.update_vibe_check_stats!
  end
end

