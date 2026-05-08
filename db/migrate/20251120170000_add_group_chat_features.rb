class AddGroupChatFeatures < ActiveRecord::Migration[8.0]
  def change
    add_column :group_chats, :invite_code, :string
    add_column :group_chats, :invite_url, :string
    add_column :group_chats, :qr_code_data, :text
    add_index :group_chats, :invite_code, unique: true
    
    add_column :group_chat_memberships, :is_muted, :boolean, default: false, null: false
    add_column :group_chat_memberships, :is_pinned, :boolean, default: false, null: false
    add_column :group_chat_memberships, :is_starred, :boolean, default: false, null: false
    add_index :group_chat_memberships, :is_muted
    add_index :group_chat_memberships, :is_pinned
    add_index :group_chat_memberships, :is_starred
  end
end

