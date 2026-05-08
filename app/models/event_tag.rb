# frozen_string_literal: true

class EventTag < ApplicationRecord
  has_many :event_taggings, dependent: :destroy
  has_many :events, through: :event_taggings

  validates :slug, presence: true, length: { maximum: 100 }
  validates :name, presence: true, length: { maximum: 255 }
  validates :display_order, numericality: { greater_than_or_equal_to: 0 }

  scope :default, -> { where(is_default: true) }
  scope :for_country, ->(country) { where(country: country) }
  scope :global, -> { where(country: nil) }
  scope :ordered, -> { order(display_order: :asc, name: :asc) }
end
