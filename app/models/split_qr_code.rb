class SplitQrCode < ApplicationRecord
  belongs_to :food_bar_order
  
  validates :qr_token, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: %w[active completed expired] }
  validates :current_participants, numericality: { greater_than_or_equal_to: 1 }
  
  before_validation :generate_qr_token, on: :create
  before_validation :set_expiry, on: :create
  
  enum :status, {
    active: 'active',
    completed: 'completed',
    expired: 'expired'
  }, prefix: true
  
  scope :active, -> { where(status: 'active').where('expires_at > ?', Time.current) }
  scope :expired, -> { where('expires_at <= ?', Time.current).or(where(status: 'expired')) }
  
  def qr_data
    {
      type: "Split",
      token: qr_token,
      order_id: food_bar_order_id,
      order_number: food_bar_order.order_number,
      total_amount: food_bar_order.total_amount,
      current_participants: current_participants,
      max_participants: max_participants,
      expires_at: expires_at&.iso8601
    }
  end
  
  def qr_url
    # URL that users will scan to join split
    "#{ENV['APP_URL'] || 'https://vibes.app'}/split/#{qr_token}"
  end

  def qr_image_url
    # Generate QR code image URL
    base_url = ENV['API_BASE_URL'] || ENV['APP_URL'] || 'https://vibesapp.digital4design.com'
    "#{base_url}/api/v1/orders/split_qr/#{qr_token}/image"
  end

  def generate_qr_image_base64
    require 'rqrcode'
    
    # Embed complete split data in QR code (including token for easy extraction)
    qr_data_json = qr_data.to_json
    qr = RQRCode::QRCode.new(qr_data_json)
    png = qr.as_png(
      bit_depth: 1,
      border_modules: 4,
      color_mode: ChunkyPNG::COLOR_GRAYSCALE,
      color: 'black',
      file: nil,
      fill: 'white',
      module_px_size: 6,
      resize_exactly_to: false,
      resize_gte_to: false,
      size: 300
    )
    
    Base64.strict_encode64(png.to_s)
  end
  
  def add_participant!(user_or_guest)
    return false if expired?
    return false if max_participants && current_participants >= max_participants
    
    increment!(:current_participants)
    
    # Create bill split for participant
    if user_or_guest.is_a?(User)
      food_bar_order.bill_splits.create!(
        user: user_or_guest,
        split_amount: calculate_split_amount,
        payment_status: 'pending'
      )
    elsif user_or_guest.is_a?(Hash)
      food_bar_order.bill_splits.create!(
        split_name: user_or_guest[:name],
        split_email: user_or_guest[:email],
        split_phone: user_or_guest[:phone],
        split_amount: calculate_split_amount,
        payment_status: 'pending'
      )
    end
    
    # Recalculate all split amounts
    recalculate_splits!
    
    # Mark as completed if max reached
    if max_participants && current_participants >= max_participants
      update!(status: 'completed')
    end
    
    true
  end
  
  def expired?
    return true if status_expired?
    return true if expires_at && Time.current >= expires_at
    false
  end
  
  def mark_expired!
    update!(status: 'expired')
  end
  
  private
  
  def generate_qr_token
    self.qr_token ||= SecureRandom.urlsafe_base64(32)
  end
  
  def set_expiry
    # Default: expires in 30 minutes
    #self.expires_at ||= 30.minutes.from_now
    self.expires_at ||= 2.days.from_now # Testing senthil
  end
  
  def calculate_split_amount
    total = food_bar_order.total_amount
    participants = current_participants
    (total / participants).round(2)
  end
  
  def recalculate_splits!
    # Recalculate all split amounts based on current participant count
    splits = food_bar_order.bill_splits
    amount_per_person = calculate_split_amount
    remainder = food_bar_order.total_amount - (amount_per_person * splits.count)
    
    splits.each_with_index do |split, index|
      # Add remainder to first person
      new_amount = index == 0 ? amount_per_person + remainder : amount_per_person
      split.update!(split_amount: new_amount)
    end
  end
end

