class CreatePromoCodes < ActiveRecord::Migration[8.0]
  def change
    create_table :promo_codes, id: :uuid do |t|
      t.uuid :event_id
      t.string :code, null: false
      t.string :label, null: false
      t.text :description
      t.string :discount_type, null: false
      t.decimal :discount_value, precision: 10, scale: 2, null: false
      t.string :currency
      t.datetime :starts_at
      t.datetime :ends_at
      t.integer :max_uses
      t.integer :uses_count, null: false, default: 0
      t.boolean :is_active, null: false, default: true
      t.timestamps
    end

    add_index :promo_codes, :code, unique: true
    add_index :promo_codes, :event_id
    add_index :promo_codes, :is_active

    add_foreign_key :promo_codes, :events, on_delete: :nullify
    add_check_constraint :promo_codes,
      "discount_type IN ('percentage', 'fixed')",
      name: 'check_promo_code_discount_type'
  end
end
