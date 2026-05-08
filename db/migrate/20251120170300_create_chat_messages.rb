class CreateChatMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :chat_messages, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :chat_id, null: false
      t.uuid :sender_id, null: false
      t.text :content, null: false
      t.string :message_type, default: 'text', null: false
      t.uuid :reply_to_id
      t.uuid :forwarded_from_id
      t.string :forwarded_from_type
      t.boolean :is_edited, default: false, null: false
      t.datetime :edited_at
      t.datetime :deleted_at
      t.boolean :is_read, default: false, null: false
      t.datetime :read_at
      t.timestamps

      t.index :chat_id
      t.index :sender_id
      t.index :reply_to_id
      t.index :forwarded_from_id
      t.index :created_at
      t.index :deleted_at
      t.index :is_read
      t.check_constraint "message_type::text = ANY (ARRAY['text'::character varying, 'image'::character varying, 'video'::character varying, 'audio'::character varying, 'location'::character varying]::text[])", name: "check_chat_message_type"
    end

    add_foreign_key :chat_messages, :chats, on_delete: :cascade
    add_foreign_key :chat_messages, :users, column: :sender_id, on_delete: :cascade
    add_foreign_key :chat_messages, :chat_messages, column: :reply_to_id, on_delete: :nullify
  end
end

