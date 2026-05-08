class WaiterCall < ApplicationRecord
  belongs_to :event
  belongs_to :user # Customer
  belongs_to :booking, optional: true
  belongs_to :order, class_name: 'FoodBarOrder', optional: true
  belongs_to :assigned_staff, class_name: 'VenueStaff', optional: true
  
  validates :call_type, presence: true, inclusion: { 
    in: %w[assistance order_help bill_request complaint emergency] 
  }
  validates :status, presence: true, inclusion: { 
    in: %w[pending acknowledged in_progress completed canceled] 
  }
  
  enum :call_type, {
    assistance: 'assistance',
    order_help: 'order_help',
    bill_request: 'bill_request',
    complaint: 'complaint',
    emergency: 'emergency'
  }, prefix: true
  
  enum :status, {
    pending: 'pending',
    acknowledged: 'acknowledged',
    in_progress: 'in_progress',
    completed: 'completed',
    canceled: 'canceled'
  }, prefix: true
  
  scope :pending, -> { where(status: 'pending') }
  scope :active, -> { where(status: ['pending', 'acknowledged', 'in_progress']) }
  scope :recent, -> { order(created_at: :desc) }
  
  after_create :notify_nearby_staff
  
  def acknowledge!(staff)
    update!(
      status: 'acknowledged',
      assigned_staff: staff,
      acknowledged_at: Time.current
    )
  end
  
  def start_service!
    update!(status: 'in_progress')
  end
  
  def complete!
    update!(status: 'completed', completed_at: Time.current)
  end
  
  def cancel!
    update!(status: 'canceled', canceled_at: Time.current)
  end
  
  def time_waiting
    return 0 if acknowledged_at.present?
    Time.current - created_at
  end
  
  def time_in_service
    return 0 unless acknowledged_at.present?
    (completed_at || Time.current) - acknowledged_at
  end
  
  private
  
  def notify_nearby_staff
    # Find all active staff for this venue
    staff_members = event.venue.venue_staff.active.where(receives_notifications: true)
    
    # Filter by geofence (within 100 meters of event)
    nearby_staff = staff_members.select do |staff|
      staff.within_event_geofence?(event, 100)
    end
    
    # Send notifications to nearby staff only
    nearby_staff.each do |staff|
      # Create notification
      Notification.create!(
        user: staff.user,
        notification_type: 'waiter_call',
        title: "Customer needs #{call_type_label}",
        message: build_notification_message,
        data: {
          waiter_call_id: id,
          event_id: event.id,
          call_type: call_type,
          table_number: table_number,
          location: location_description,
          priority: call_type_emergency? ? 'high' : 'normal'
        }.to_json
      )
      
      # Send push notification via FCM
      if FcmService.configured?
        FcmService.send_to_user(
          staff.user,
          title: notification.title,
          body: notification.message,
          data: notification.metadata_hash.merge(
            notification_id: notification.id.to_s,
            notification_type: notification.notification_type
          )
        )
      end
    end
  end
  
  def call_type_label
    {
      'assistance' => 'assistance',
      'order_help' => 'help with their order',
      'bill_request' => 'the bill',
      'complaint' => 'to file a complaint',
      'emergency' => 'EMERGENCY ASSISTANCE'
    }[call_type] || 'assistance'
  end
  
  def build_notification_message
    msg = "Customer at "
    msg += table_number.present? ? "Table #{table_number}" : location_description || "event"
    msg += " needs #{call_type_label}"
    msg += ": #{message}" if message.present?
    msg
  end
end

