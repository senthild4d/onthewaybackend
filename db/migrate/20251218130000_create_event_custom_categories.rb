class CreateEventCustomCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :event_custom_categories, id: :uuid do |t|
      t.references :event, null: false, foreign_key: true, type: :uuid, index: true
      t.string :name, null: false, limit: 255
      t.text :description
      
      t.timestamps
    end
    
    add_index :event_custom_categories, :name
    add_index :event_custom_categories, [:event_id, :name], unique: true, name: 'index_event_custom_categories_on_event_and_name'
  end
end

