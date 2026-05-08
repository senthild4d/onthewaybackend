class FoodBarOrder < ApplicationRecord
  belongs_to :event
  belongs_to :user
  belongs_to :booking, optional: true
  belongs_to :payment_transaction, optional: true
  has_many :food_bar_order_items, dependent: :destroy
  has_many :menu_items, through: :food_bar_order_items
  has_many :bill_splits, dependent: :destroy
  has_many :split_participants, through: :bill_splits, source: :user
  has_one :split_qr_code, dependent: :destroy
  has_many :waiter_calls, foreign_key: 'order_id', dependent: :nullify
  
  validates :order_number, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { 
    in: %w[pending confirmed preparing ready delivered completed canceled] 
  }
  validates :order_type, presence: true, inclusion: { in: %w[food bar both] }
  validates :payment_status, presence: true, inclusion: { 
    in: %w[pending paid failed refunded split_pending] 
  }
  validates :subtotal, :total_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :tip_amount, :tax, numericality: { greater_than_or_equal_to: 0 }
  validates :split_count, numericality: { greater_than_or_equal_to: 1 }
  validate :time_window_start_before_end
  validate :time_window_within_event
  
  before_validation :generate_order_number, on: :create
  before_save :calculate_total
  
  # Enums
  enum :status, {
    pending: 'pending',
    confirmed: 'confirmed',
    preparing: 'preparing',
    ready: 'ready',
    delivered: 'delivered',
    completed: 'completed',
    canceled: 'canceled'
  }, prefix: true
  
  enum :payment_status, {
    pending: 'pending',
    paid: 'paid',
    failed: 'failed',
    refunded: 'refunded',
    split_pending: 'split_pending'
  }, prefix: :payment
  
  # Scopes
  scope :active, -> { where.not(status: 'canceled') }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_type, ->(type) { where(order_type: type) }
  scope :recent, -> { order(created_at: :desc) }
  scope :for_event, ->(event_id) { where(event_id: event_id) }
  
  def confirm!
    update!(
      status: 'confirmed',
      confirmed_at: Time.current,
      ordered_at: ordered_at || Time.current
    )
  end
  
  def mark_preparing!
    update!(status: 'preparing', preparing_at: Time.current)
  end
  
  def mark_ready!
    update!(status: 'ready', ready_at: Time.current)
  end
  
  def mark_delivered!
    update!(status: 'delivered', delivered_at: Time.current)
  end
  
  def complete!
    update!(status: 'completed', completed_at: Time.current)
  end
  
  def cancel!
    update!(status: 'canceled', canceled_at: Time.current)
  end
  
  def calculate_split_amounts(user_ids_or_splits)
    return {} unless user_ids_or_splits.present?
    
    split_count = user_ids_or_splits.size
    amount_per_person = (total_amount / split_count).round(2)
    remainder = total_amount - (amount_per_person * split_count)
    
    splits = {}
    user_ids_or_splits.each_with_index do |item, index|
      key = item.is_a?(Hash) ? (item[:user_id] || item['user_id']) : item
      # Add remainder to first person
      splits[key] = index == 0 ? amount_per_person + remainder : amount_per_person
    end
    
    splits
  end
  
  def create_splits!(participants)
    return false if bill_splits.any?
    
    splits = calculate_split_amounts(participants)
    
    FoodBarOrder.transaction do
      participants.each_with_index do |participant, index|
        if participant.is_a?(Hash) || participant.is_a?(ActionController::Parameters)
          # Support for non-registered users
          bill_splits.create!(
            user_id: participant[:user_id] || participant['user_id'],
            split_name: participant[:name] || participant['name'],
            split_email: participant[:email] || participant['email'],
            split_phone: participant[:phone] || participant['phone'],
            split_amount: splits[participant[:user_id] || participant['user_id'] || index],
            payment_status: 'pending'
          )
        else
          # Registered user ID
          bill_splits.create!(
            user_id: participant,
            split_amount: splits[participant],
            payment_status: 'pending'
          )
        end
      end
      
      update!(
        is_split_bill: true,
        split_count: participants.size,
        payment_status: 'split_pending'
      )
    end
    
    true
  end
  
  def all_splits_paid?
    return false unless is_split_bill?
    bill_splits.all? { |split| split.payment_status == 'paid' }
  end
  
  def mark_as_fully_paid!
    if is_split_bill? && all_splits_paid?
      update!(payment_status: 'paid')
    elsif !is_split_bill?
      update!(payment_status: 'paid')
    end
  end
  
  # QR code split methods
  def generate_split_qr_code!(max_participants: nil)
    return split_qr_code if split_qr_code.present?
    
    create_split_qr_code!(
      max_participants: max_participants,
      current_participants: 1, # Order creator is first participant
      status: 'active'
    )
  end
  
  def qr_code_active?
    split_qr_code.present? && split_qr_code.status_active? && !split_qr_code.expired?
  end
  
  private
  
  def generate_order_number
    return if order_number.present?
    
    # Format: ORD-YYYYMMDD-XXXX
    date_part = Time.current.strftime('%Y%m%d')
    random_part = SecureRandom.hex(2).upcase
    self.order_number = "ORD-#{date_part}-#{random_part}"
  end
  
  def calculate_total
    self.total_amount = subtotal + tax + tip_amount
  end

  def time_window_start_before_end
    return if time_window_start.blank? || time_window_end.blank?

    if time_window_end < time_window_start
      errors.add(:time_window_end, 'must be after or equal to start time')
    end
  end

  def time_window_within_event
    return if event.blank?
    return if time_window_start.blank? && time_window_end.blank?

    event_start = event.starts_at
    event_end = event.ends_at
    return if event_start.blank? || event_end.blank?

    if time_window_start.present? && (time_window_start < event_start || time_window_start > event_end)
      errors.add(:time_window_start, 'must be within event time range')
    end

    if time_window_end.present? && (time_window_end < event_start || time_window_end > event_end)
      errors.add(:time_window_end, 'must be within event time range')
    end
  end
end
