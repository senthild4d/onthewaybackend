class CategoriesGroup < ApplicationRecord
  self.table_name = 'categories_groups'

  # Slug for the group that holds venue-type categories (restaurant, pub, cinema, etc.)
  VENUE_CATEGORIES_SLUG = 'venue-categories'

  has_many :categories, dependent: :destroy

  validates :name, presence: true, length: { maximum: 100 }
  validates :slug, presence: true, uniqueness: true, length: { maximum: 100 }
  validates :display_order, numericality: { greater_than_or_equal_to: 0 }

  scope :venue_categories_group, -> { where(slug: VENUE_CATEGORIES_SLUG) }
end

