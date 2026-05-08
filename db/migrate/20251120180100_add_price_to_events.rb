class AddPriceToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :price, :decimal, precision: 10, scale: 2, default: 0.0, null: false
    add_column :events, :currency, :string, default: 'USD', null: false
    add_column :events, :is_free, :boolean, default: true, null: false
    add_index :events, :is_free
    add_index :events, :price
  end
end

