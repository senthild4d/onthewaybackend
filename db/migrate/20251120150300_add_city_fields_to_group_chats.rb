class AddCityFieldsToGroupChats < ActiveRecord::Migration[8.0]
  def change
    add_column :group_chats, :city, :string
    add_column :group_chats, :country, :string
    add_column :group_chats, :is_city_based, :boolean, default: false, null: false
    
    add_index :group_chats, [:city, :country]
    add_index :group_chats, :is_city_based
    add_index :group_chats, [:is_city_based, :city, :country], name: "index_group_chats_city_based"
  end
end

