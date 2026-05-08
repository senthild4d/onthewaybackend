class ArtistCategory < ApplicationRecord
  belongs_to :user
  belongs_to :category

  validates :user_id, presence: true
  validates :category_id, presence: true
  validates :source, presence: true
end

