class AddVenueIdToPromoCodes < ActiveRecord::Migration[7.0]
  def change
    add_reference :promo_codes, :venue, type: :uuid, foreign_key: true, index: true
  end
end
