class CreateCategoriesGroupAndCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories_groups, id: :uuid do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.integer :display_order, null: false, default: 0
      t.timestamps
    end

    add_index :categories_groups, :slug, unique: true
    add_index :categories_groups, :display_order

    create_table :categories, id: :uuid do |t|
      t.uuid :categories_group_id, null: false
      t.string :name, null: false
      t.string :slug, null: false
      t.string :icon_key
      t.integer :display_order, null: false, default: 0
      t.timestamps
    end

    add_index :categories, :slug, unique: true
    add_index :categories, :display_order
    add_index :categories, [:categories_group_id, :name], unique: true

    add_foreign_key :categories, :categories_groups, on_delete: :cascade
  end
end

