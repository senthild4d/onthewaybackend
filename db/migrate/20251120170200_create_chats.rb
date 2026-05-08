class CreateChats < ActiveRecord::Migration[8.0]
  def change
    create_table :chats, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :user1_id, null: false
      t.uuid :user2_id, null: false
      t.datetime :last_message_at
      t.boolean :user1_blocked, default: false, null: false
      t.boolean :user2_blocked, default: false, null: false
      t.boolean :user1_muted, default: false, null: false
      t.boolean :user2_muted, default: false, null: false
      t.boolean :user1_pinned, default: false, null: false
      t.boolean :user2_pinned, default: false, null: false
      t.boolean :user1_archived, default: false, null: false
      t.boolean :user2_archived, default: false, null: false
      t.timestamps

      t.index [:user1_id, :user2_id], unique: true, name: "index_chats_users_unique"
      t.index :user1_id
      t.index :user2_id
      t.index :last_message_at
    end

    add_foreign_key :chats, :users, column: :user1_id, on_delete: :cascade
    add_foreign_key :chats, :users, column: :user2_id, on_delete: :cascade
  end
end

