class VenueStaff < ApplicationRecord
  self.table_name = 'venue_staff'
  belongs_to :venue
  belongs_to :user
  has_many :waiter_calls, foreign_key: 'assigned_staff_id', dependent: :nullify
  
  validates :role, presence: true, inclusion: { in: %w[waiter bartender chef manager host] }
  validates :status, presence: true, inclusion: { in: %w[active on_break off_duty inactive] }
  validates :user_id, uniqueness: { scope: :venue_id }
  
  enum :role, {
    waiter: 'waiter',
    bartender: 'bartender',
    chef: 'chef',
    manager: 'manager',
    host: 'host'
  }, prefix: true
  
  enum :status, {
    active: 'active',
    on_break: 'on_break',
    off_duty: 'off_duty',
    inactive: 'inactive'
  }, prefix: true
  
  scope :active, -> { where(status: 'active') }
  scope :on_duty, -> { where(status: ['active', 'on_break']) }
  scope :by_role, ->(role) { where(role: role) }
  
  def update_location(latitude, longitude)
    update!(
      current_latitude: latitude,
      current_longitude: longitude,
      last_location_update: Time.current
    )
  end
  
  def within_event_geofence?(event, radius_meters = 100)
    return false unless current_latitude && current_longitude
    return false unless event.coordinates?
    
    event_location = event.event_location
    distance = calculate_distance(
      current_latitude,
      current_longitude,
      event_location[:latitude],
      event_location[:longitude]
    )
    
    distance <= radius_meters
  end
  
  def on_shift?
    return false if status_off_duty? || status_inactive?
    return true if shift_start_at.nil? && shift_end_at.nil?
    
    now = Time.current
    (shift_start_at.nil? || now >= shift_start_at) &&
    (shift_end_at.nil? || now <= shift_end_at)
  end
  
  def available_for_calls?
    status_active? && receives_notifications? && on_shift?
  end
  
  private
  
  # Haversine formula for distance calculation
  def calculate_distance(lat1, lon1, lat2, lon2)
    rad_per_deg = Math::PI / 180
    rkm = 6371000 # Earth radius in meters
    
    dlat_rad = (lat2 - lat1) * rad_per_deg
    dlon_rad = (lon2 - lon1) * rad_per_deg
    
    lat1_rad = lat1 * rad_per_deg
    lat2_rad = lat2 * rad_per_deg
    
    a = Math.sin(dlat_rad / 2)**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(dlon_rad / 2)**2
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    
    rkm * c # Distance in meters
  end
end

