class AddCategoryTypeToMenuCategories < ActiveRecord::Migration[8.0]
  def change
    add_column :menu_categories, :category_type, :string, default: 'other', null: false
    add_index :menu_categories, :category_type

    add_check_constraint :menu_categories,
      "category_type IN ('food', 'bar', 'drinks', 'dessert', 'appetizer', 'main', 'other')",
      name: 'check_menu_category_type'
  end
end
