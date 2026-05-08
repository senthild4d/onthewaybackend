class CreateGroupChatMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :group_chat_memberships, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :group_chat_id, null: false
      t.uuid :user_id, null: false
      t.string :role, default: 'member', null: false
      t.datetime :joined_at, null: false
      t.datetime :last_read_at
      t.timestamps

      t.index [:group_chat_id, :user_id], unique: true, name: "index_group_chat_memberships_group_chat_user_unique"
      t.index :group_chat_id
      t.index :user_id
      t.index :role
      t.check_constraint "role::text = ANY (ARRAY['admin'::character varying, 'member'::character varying]::text[])", name: "check_group_chat_membership_role"
    end

    add_foreign_key :group_chat_memberships, :group_chats, on_delete: :cascade
    add_foreign_key :group_chat_memberships, :users, on_delete: :cascade
  end
end

