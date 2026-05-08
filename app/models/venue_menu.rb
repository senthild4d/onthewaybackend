class VenueMenu < ApplicationRecord
  belongs_to :venue
  has_many :venue_menu_categories, dependent: :destroy
  has_many :venue_menu_items, through: :venue_menu_categories
  has_one_attached :image
  
  validates :name, presence: true
  validates :menu_type, presence: true, inclusion: { in: %w[food bar both] }
  
  scope :active, -> { where(is_active: true) }
  scope :by_type, ->(type) { where(menu_type: type) }
  scope :food_menus, -> { where(menu_type: %w[food both]) }
  scope :bar_menus, -> { where(menu_type: %w[bar both]) }
  
  def available_now?
    is_active && 
    (available_from.nil? || Time.current >= available_from) &&
    (available_until.nil? || Time.current <= available_until)
  end
end

