class AddDescriptionAndAddressToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :description, :text
    add_column :users, :address, :text
  end
end
