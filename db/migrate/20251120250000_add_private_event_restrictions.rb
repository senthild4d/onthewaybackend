class AddPrivateEventRestrictions < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :pre_booking_price, :decimal, precision: 10, scale: 2
    add_column :events, :pre_booking_deadline, :datetime
    add_column :events, :id_required, :boolean, default: false, null: false
    add_column :events, :id_requirement_description, :text
    add_column :events, :dress_code, :text
    add_column :events, :restrictions, :text
    add_column :events, :access_instructions, :text
    
    add_index :events, :pre_booking_deadline
    add_index :events, :id_required
  end
end

