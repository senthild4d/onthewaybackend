class MenuItem < ApplicationRecord
  belongs_to :menu_category
  has_many :food_bar_order_items, dependent: :restrict_with_error
  alias_method :order_items, :food_bar_order_items
  has_one_attached :image
  
  validates :name, presence: true
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, presence: true
  
  scope :available, -> { where(is_available: true) }
  scope :vegetarian, -> { where(is_vegetarian: true) }
  scope :vegan, -> { where(is_vegan: true) }
  scope :gluten_free, -> { where(is_gluten_free: true) }
  scope :alcoholic, -> { where(contains_alcohol: true) }
  scope :non_alcoholic, -> { where(contains_alcohol: false) }
  scope :ordered, -> { order(:display_order, :name) }
  
  def allergens_list
    allergens.present? ? JSON.parse(allergens) : []
  rescue JSON::ParserError
    []
  end
  
  def allergens_list=(list)
    self.allergens = list.to_json
  end
  
  def dietary_info
    info = []
    info << 'Vegetarian' if is_vegetarian
    info << 'Vegan' if is_vegan
    info << 'Gluten-Free' if is_gluten_free
    info << 'Contains Alcohol' if contains_alcohol
    info
  end
end
