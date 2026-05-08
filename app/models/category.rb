class Category < ApplicationRecord
  belongs_to :categories_group
  has_many :artist_categories, dependent: :destroy
  has_many :users, through: :artist_categories
  has_many :event_categories, dependent: :destroy
  has_many :events, through: :event_categories
  has_many :venue_categories, dependent: :destroy
  has_many :venues, through: :venue_categories

  validates :name, presence: true, length: { maximum: 100 }
  validates :slug, presence: true, uniqueness: true, length: { maximum: 100 }
  validates :display_order, numericality: { greater_than_or_equal_to: 0 }

  # Categories that can be assigned to venues (e.g. restaurant, pub, cinema)
  scope :for_venues, -> { joins(:categories_group).where(categories_groups: { slug: CategoriesGroup::VENUE_CATEGORIES_SLUG }) }
end

