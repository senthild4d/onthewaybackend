class EventBoost < ApplicationRecord
  belongs_to :event
  belongs_to :created_by, class_name: 'User'

  # Performance goal options
  PERFORMANCE_GOALS = %w[page_views link_clicks daily_reach].freeze

  # Gender targeting options
  GENDERS = %w[all male female other].freeze

  # Status options
  STATUSES = %w[draft pending_review active paused completed rejected cancelled].freeze

  # Validations
  validates :performance_goal, presence: true, inclusion: { in: PERFORMANCE_GOALS }
  validates :target_gender, presence: true, inclusion: { in: GENDERS }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :starts_at, presence: true
  validates :ends_at, presence: true
  validates :target_age_min, numericality: { 
    only_integer: true, 
    greater_than_or_equal_to: 0, 
    less_than_or_equal_to: 120 
  }, allow_nil: true
  validates :target_age_max, numericality: { 
    only_integer: true, 
    greater_than_or_equal_to: 0, 
    less_than_or_equal_to: 120 
  }, allow_nil: true
  validates :geo_fence_radius_km, numericality: { 
    greater_than: 0, 
    less_than_or_equal_to: 500 
  }, allow_nil: true
  validates :daily_budget, numericality: { greater_than: 0 }, allow_nil: true
  validates :total_budget, numericality: { greater_than: 0 }, allow_nil: true
  validates :geo_fence_latitude, numericality: { 
    greater_than_or_equal_to: -90, 
    less_than_or_equal_to: 90 
  }, allow_nil: true
  validates :geo_fence_longitude, numericality: { 
    greater_than_or_equal_to: -180, 
    less_than_or_equal_to: 180 
  }, allow_nil: true
  validate :ends_after_starts
  validate :age_range_valid

  # Scopes
  scope :draft, -> { where(status: 'draft') }
  scope :pending_review, -> { where(status: 'pending_review') }
  scope :active, -> { where(status: 'active') }
  scope :paused, -> { where(status: 'paused') }
  scope :completed, -> { where(status: 'completed') }
  scope :rejected, -> { where(status: 'rejected') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :running, -> { active.where('starts_at <= ? AND ends_at >= ?', Time.current, Time.current) }
  scope :scheduled, -> { active.where('starts_at > ?', Time.current) }
  scope :by_performance_goal, ->(goal) { where(performance_goal: goal) }

  # Status transition methods
  def submit_for_review!
    return false unless status == 'draft'
    update!(status: 'pending_review')
  end

  def approve!
    return false unless status == 'pending_review'
    update!(status: 'active', approved_at: Time.current)
  end

  def reject!(reason = nil)
    return false unless status == 'pending_review'
    update!(status: 'rejected', rejected_at: Time.current, rejection_reason: reason)
  end

  def pause!
    return false unless status == 'active'
    update!(status: 'paused', paused_at: Time.current)
  end

  def resume!
    return false unless status == 'paused'
    update!(status: 'active', paused_at: nil)
  end

  def complete!
    return false unless %w[active paused].include?(status)
    update!(status: 'completed', completed_at: Time.current)
  end

  def cancel!
    return false if %w[completed cancelled rejected].include?(status)
    update!(status: 'cancelled', cancelled_at: Time.current)
  end

  # Status checks
  def is_active?
    status == 'active'
  end

  def is_running?
    is_active? && Time.current.between?(starts_at, ends_at)
  end

  def is_scheduled?
    is_active? && starts_at > Time.current
  end

  def is_ended?
    ends_at < Time.current
  end

  def can_edit?
    %w[draft rejected].include?(status)
  end

  def can_cancel?
    !%w[completed cancelled rejected].include?(status)
  end

  # Geo-fence helpers
  def has_geo_fence?
    geo_fence_latitude.present? && geo_fence_longitude.present? && geo_fence_radius_km.present?
  end

  def geo_fence_location
    return nil unless has_geo_fence?
    {
      latitude: geo_fence_latitude.to_f,
      longitude: geo_fence_longitude.to_f,
      radius_km: geo_fence_radius_km.to_f,
      address: geo_fence_address,
      city: geo_fence_city,
      region: geo_fence_region,
      country: geo_fence_country
    }
  end

  # Audience targeting summary
  def target_audience
    {
      age_range: {
        min: target_age_min || 18,
        max: target_age_max || 65
      },
      gender: target_gender,
      location: geo_fence_location
    }
  end

  # Performance metrics
  def performance_metrics
    {
      impressions: impressions_count,
      page_views: page_views_count,
      link_clicks: link_clicks_count,
      unique_reach: unique_reach_count,
      click_through_rate: calculate_ctr,
      cost_per_click: calculate_cpc,
      cost_per_view: calculate_cpv
    }
  end

  def calculate_ctr
    return 0 if impressions_count.zero?
    ((link_clicks_count.to_f / impressions_count) * 100).round(2)
  end

  def calculate_cpc
    return 0 if link_clicks_count.zero?
    (amount_spent.to_f / link_clicks_count).round(2)
  end

  def calculate_cpv
    return 0 if page_views_count.zero?
    (amount_spent.to_f / page_views_count).round(2)
  end

  # Budget helpers
  def budget_remaining
    return nil unless total_budget.present?
    [total_budget - (amount_spent || 0), 0].max
  end

  def budget_spent_percentage
    return 0 unless total_budget.present? && total_budget > 0
    ((amount_spent || 0) / total_budget * 100).round(2)
  end

  def is_budget_exhausted?
    return false unless total_budget.present?
    (amount_spent || 0) >= total_budget
  end

  # Duration helpers
  def duration_days
    return 0 unless starts_at.present? && ends_at.present?
    ((ends_at - starts_at) / 1.day).ceil
  end

  def days_remaining
    return 0 if is_ended?
    return duration_days unless is_running?
    ((ends_at - Time.current) / 1.day).ceil
  end

  # Increment metrics (for tracking)
  def record_impression!
    increment!(:impressions_count)
  end

  def record_page_view!
    increment!(:page_views_count)
  end

  def record_link_click!
    increment!(:link_clicks_count)
  end

  def record_unique_reach!
    increment!(:unique_reach_count)
  end

  private

  def ends_after_starts
    return unless starts_at.present? && ends_at.present?
    if ends_at <= starts_at
      errors.add(:ends_at, 'must be after start time')
    end
  end

  def age_range_valid
    return unless target_age_min.present? && target_age_max.present?
    if target_age_min > target_age_max
      errors.add(:target_age_max, 'must be greater than or equal to minimum age')
    end
  end
end

