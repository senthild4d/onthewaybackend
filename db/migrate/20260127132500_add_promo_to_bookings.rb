class AddPromoToBookings < ActiveRecord::Migration[8.0]
  def change
    add_column :bookings, :promo_code_id, :uuid
    add_column :bookings, :promo_code, :string
    add_column :bookings, :original_price, :decimal, precision: 10, scale: 2
    add_column :bookings, :discount_amount, :decimal, precision: 10, scale: 2

    add_index :bookings, :promo_code_id
    add_foreign_key :bookings, :promo_codes, column: :promo_code_id, on_delete: :nullify
  end
end
