class AddMessageFeatures < ActiveRecord::Migration[8.0]
  def change
    add_column :group_chat_messages, :is_edited, :boolean, default: false, null: false
    add_column :group_chat_messages, :edited_at, :datetime
    add_column :group_chat_messages, :forwarded_from_id, :uuid
    add_column :group_chat_messages, :forwarded_from_type, :string
    add_index :group_chat_messages, :is_edited
    add_index :group_chat_messages, [:forwarded_from_type, :forwarded_from_id]
    
    add_foreign_key :group_chat_messages, :group_chat_messages, column: :forwarded_from_id, on_delete: :nullify
  end
end

