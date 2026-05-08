class AddAgePricingToEventsAndBookings < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :adult_price, :decimal, precision: 10, scale: 2
    add_column :events, :child_price, :decimal, precision: 10, scale: 2
    add_column :events, :infant_price, :decimal, precision: 10, scale: 2
    add_column :events, :pet_price, :decimal, precision: 10, scale: 2

    add_column :bookings, :adults_count, :integer, default: 1, null: false
    add_column :bookings, :children_count, :integer, default: 0, null: false
    add_column :bookings, :infants_count, :integer, default: 0, null: false
    add_column :bookings, :pets_count, :integer, default: 0, null: false
  end
end
