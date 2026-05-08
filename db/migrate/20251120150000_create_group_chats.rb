class CreateGroupChats < ActiveRecord::Migration[8.0]
  def change
    create_table :group_chats, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :name
      t.text :description
      t.uuid :created_by_id, null: false
      t.string :status, default: 'active', null: false
      t.datetime :last_message_at
      t.timestamps

      t.index :created_by_id
      t.index :status
      t.index :last_message_at
      t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'archived'::character varying]::text[])", name: "check_group_chat_status"
    end

    add_foreign_key :group_chats, :users, column: :created_by_id, on_delete: :restrict
  end
end

