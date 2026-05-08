class CreateEventInterests < ActiveRecord::Migration[8.0]
  def change
    create_table :event_interests, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid, index: true
      t.references :event, null: false, foreign_key: true, type: :uuid, index: true
      
      t.timestamps
    end
    
    # Add unique constraint for user_id and event_id combination
    add_index :event_interests, [:user_id, :event_id], unique: true, name: 'index_event_interests_user_event_unique'
  end
end

