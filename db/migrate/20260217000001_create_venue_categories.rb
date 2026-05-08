class CreateVenueCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :venue_categories, id: :uuid do |t|
      t.uuid :venue_id, null: false
      t.uuid :category_id, null: false
      t.string :source, default: 'manual', null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end

    add_index :venue_categories, :venue_id
    add_index :venue_categories, :category_id
    add_index :venue_categories, [:venue_id, :category_id], unique: true
    add_foreign_key :venue_categories, :venues, on_delete: :cascade
    add_foreign_key :venue_categories, :categories, on_delete: :cascade
  end
end
