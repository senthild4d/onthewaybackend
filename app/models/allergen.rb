class Allergen < ApplicationRecord
  validates :code, presence: true, uniqueness: true
  validates :label, presence: true
end
