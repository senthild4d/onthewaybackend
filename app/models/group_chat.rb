require 'rqrcode'
require 'base64'

class GroupChat < ApplicationRecord
  # Associations
  belongs_to :created_by, class_name: 'User'
  has_many :group_chat_memberships, dependent: :destroy
  has_many :members, through: :group_chat_memberships, source: :user
  has_many :messages, class_name: 'GroupChatMessage', dependent: :destroy

  # Enums
  enum :status, { active: 'active', archived: 'archived' }, prefix: true

  # Validations
  validates :name, length: { maximum: 100 }
  validates :status, presence: true, inclusion: { in: statuses.keys }
  validates :created_by_id, presence: true

  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :recent, -> { order(last_message_at: :desc, created_at: :desc) }
  scope :city_based, -> { where(is_city_based: true) }
  scope :by_city, ->(city, country = nil) { 
    query = where(city: city, is_city_based: true)
    query = query.where(country: country) if country.present?
    query
  }

  # Callbacks
  after_create :add_creator_as_admin
  after_create :update_last_message_at
  after_create :generate_invite_code

  def add_member(user, role: 'member')
    return if members.include?(user)

    group_chat_memberships.create!(
      user: user,
      role: role,
      joined_at: Time.current
    )
  end

  def remove_member(user)
    group_chat_memberships.find_by(user: user)&.destroy
  end

  def member?(user)
    members.include?(user)
  end

  def admin?(user)
    group_chat_memberships.find_by(user: user, role: 'admin').present?
  end

  def update_last_message_at
    update_column(:last_message_at, Time.current) if last_message_at.nil?
  end

  def generate_invite_code
    return if invite_code.present?

    code = SecureRandom.alphanumeric(8).upcase
    # Ensure uniqueness
    code = SecureRandom.alphanumeric(8).upcase while GroupChat.exists?(invite_code: code)
    
    update_columns(
      invite_code: code,
      invite_url: "#{Rails.application.config.action_mailer.default_url_options[:host]}/join/#{code}"
    )
  end

  def regenerate_invite_code
    generate_invite_code
  end

  def generate_qr_code
    return qr_code_data if qr_code_data.present?

    qr = RQRCode::QRCode.new(invite_url)
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
    
    base64_data = Base64.strict_encode64(png.to_s)
    update_column(:qr_code_data, "data:image/png;base64,#{base64_data}")
    qr_code_data
  end

  def owner?(user)
    created_by_id == user.id
  end

  def can_manage?(user)
    owner?(user) || admin?(user)
  end

  private

  def add_creator_as_admin
    group_chat_memberships.create!(
      user: created_by,
      role: 'admin',
      joined_at: Time.current
    )
  end
end

