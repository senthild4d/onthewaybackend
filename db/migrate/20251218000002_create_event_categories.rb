class CreateEventCategories < ActiveRecord::Migration[8.0]
  def change
    # Event Categories join table - allows events to have multiple categories like artists
    create_table :event_categories, id: :uuid do |t|
      t.uuid :event_id, null: false
      t.uuid :category_id, null: false
      t.string :source, null: false, default: 'manual' # manual, auto, system
      
      t.timestamps
    end
    
    add_index :event_categories, :event_id
    add_index :event_categories, :category_id
    add_index :event_categories, [:event_id, :category_id], unique: true, name: 'index_event_categories_on_event_id_and_category_id'
    
    add_foreign_key :event_categories, :events, on_delete: :cascade
    add_foreign_key :event_categories, :categories, on_delete: :cascade
  end
end


