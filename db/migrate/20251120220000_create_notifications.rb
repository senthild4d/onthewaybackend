class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :user_id, null: false
      t.string :notification_type, null: false
      t.string :title, null: false
      t.text :message, null: false
      t.jsonb :metadata, default: {}, null: false
      t.boolean :read, default: false, null: false
      t.datetime :read_at
      t.timestamps

      t.index :user_id
      t.index :notification_type
      t.index :read
      t.index [:user_id, :read]
      t.index :created_at
    end

    add_foreign_key :notifications, :users, on_delete: :cascade
  end
end

