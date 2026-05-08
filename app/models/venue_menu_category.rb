class VenueMenuCategory < ApplicationRecord
  belongs_to :venue_menu
  has_many :venue_menu_items, dependent: :destroy
  has_one_attached :image
  
  validates :name, presence: true
  validates :category_type, inclusion: { 
    in: %w[food bar drinks dessert appetizer main other],
    allow_nil: true
  }
  
  scope :active, -> { where(is_active: true) }
  scope :by_type, ->(type) { where(category_type: type) }
  scope :ordered, -> { order(:display_order, :name) }
  
  def food?
    category_type.in?(%w[food appetizer main dessert])
  end
  
  def bar?
    category_type.in?(%w[bar drinks])
  end
end

