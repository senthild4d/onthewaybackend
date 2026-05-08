class CreateAllergens < ActiveRecord::Migration[8.0]
  def change
    create_table :allergens, id: :uuid do |t|
      t.string :code, null: false
      t.string :label, null: false
      t.text :description
      t.timestamps
    end

    add_index :allergens, :code, unique: true
    add_index :allergens, :label
  end
end
