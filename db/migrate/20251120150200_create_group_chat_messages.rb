class CreateGroupChatMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :group_chat_messages, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :group_chat_id, null: false
      t.uuid :user_id, null: false
      t.text :content, null: false
      t.string :message_type, default: 'text', null: false
      t.uuid :reply_to_id
      t.datetime :deleted_at
      t.timestamps

      t.index :group_chat_id
      t.index :user_id
      t.index :reply_to_id
      t.index :created_at
      t.index :deleted_at
      t.check_constraint "message_type::text = ANY (ARRAY['text'::character varying, 'image'::character varying, 'video'::character varying, 'audio'::character varying, 'location'::character varying]::text[])", name: "check_group_chat_message_type"
    end

    add_foreign_key :group_chat_messages, :group_chats, on_delete: :cascade
    add_foreign_key :group_chat_messages, :users, on_delete: :cascade
    add_foreign_key :group_chat_messages, :group_chat_messages, column: :reply_to_id, on_delete: :nullify
  end
end

