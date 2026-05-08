class AddSmokingToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :smoking, :string, limit: 20
    
    add_index :events, :smoking
    
    # Add check constraint for smoking values
    add_check_constraint :events,
      "smoking IS NULL OR smoking IN ('yes', 'no', '2 zones', 'private zone')",
      name: 'check_event_smoking'
  end
end

