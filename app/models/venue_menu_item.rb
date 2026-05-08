class VenueMenuItem < ApplicationRecord
  belongs_to :venue_menu_category
  # Note: Orders are for events, not venues directly, so venue menu items are not directly orderable
  # Venue menus serve as templates/catalogs for the venue
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
    allergens.present? && allergens.is_a?(Array) ? allergens : []
  rescue
    []
  end
  
  def allergens_list=(list)
    self.allergens = list.is_a?(Array) ? list : []
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

