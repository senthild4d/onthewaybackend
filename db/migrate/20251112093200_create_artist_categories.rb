class CreateArtistCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :artist_categories, id: :uuid do |t|
      t.uuid :user_id, null: false
      t.uuid :category_id, null: false
      t.string :source, null: false, default: 'onboarding'
      t.timestamps
    end

    add_index :artist_categories, [:user_id, :category_id], unique: true
    add_index :artist_categories, :user_id
    add_index :artist_categories, :category_id

    add_foreign_key :artist_categories, :users, on_delete: :cascade
    add_foreign_key :artist_categories, :categories, on_delete: :cascade
  end
end

