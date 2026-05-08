class CreateFavorites < ActiveRecord::Migration[8.0]
  def change
    create_table :favorites, id: :uuid do |t|
      t.uuid :user_id, null: false
      t.uuid :property_id, null: false
      t.timestamps
    end

    add_index :favorites, [:user_id, :property_id], unique: true
    add_index :favorites, :property_id

    add_foreign_key :favorites, :users, on_delete: :cascade
    add_foreign_key :favorites, :properties, on_delete: :cascade
  end
end

