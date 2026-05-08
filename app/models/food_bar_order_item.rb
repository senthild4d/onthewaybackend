class FoodBarOrderItem < ApplicationRecord
  belongs_to :food_bar_order
  belongs_to :menu_item
  
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :unit_price, :total_price, numericality: { greater_than_or_equal_to: 0 }
  
  before_validation :set_prices, on: :create
  before_validation :calculate_total_price, on: :create
  before_save :calculate_total_price
  
  def customizations_hash
    customizations.present? ? JSON.parse(customizations) : {}
  rescue JSON::ParserError
    {}
  end
  
  def customizations_hash=(hash)
    self.customizations = hash.to_json
  end
  
  private
  
  def set_prices
    self.unit_price ||= menu_item.price if menu_item
  end
  
  def calculate_total_price
    return if unit_price.nil? || quantity.nil?
    self.total_price = unit_price * quantity
  end
end
