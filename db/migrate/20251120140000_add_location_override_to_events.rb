class AddLocationOverrideToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :address1, :string
    add_column :events, :address2, :string
    add_column :events, :city, :string
    add_column :events, :region, :string
    add_column :events, :postal_code, :string
    add_column :events, :country, :string
    add_column :events, :latitude, :decimal, precision: 10, scale: 7
    add_column :events, :longitude, :decimal, precision: 10, scale: 7
    
    # Add validation constraints
    add_check_constraint :events, "latitude IS NULL OR (latitude >= -90 AND latitude <= 90)", name: 'check_event_latitude'
    add_check_constraint :events, "longitude IS NULL OR (longitude >= -180 AND longitude <= 180)", name: 'check_event_longitude'
  end
end





