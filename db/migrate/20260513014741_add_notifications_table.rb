class AddNotificationsTable < ActiveRecord::Migration[8.0]
  def change
    return if table_exists?(:notifications)

    create_table :notifications, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :user_id, null: false
      t.string :notification_type, null: false
      t.string :title, null: false
      t.text :body
      t.jsonb :data, default: {}, null: false
      t.boolean :read, default: false, null: false
      t.datetime :read_at
      t.string :related_type
      t.uuid :related_id
      t.timestamps

      t.index :user_id
      t.index :notification_type
      t.index :read
      t.index [:user_id, :read]
      t.index :created_at
      t.index [:related_type, :related_id]
    end

    add_foreign_key :notifications, :users, on_delete: :cascade
  end
end
