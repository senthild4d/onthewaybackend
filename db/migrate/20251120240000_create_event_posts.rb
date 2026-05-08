class CreateEventPosts < ActiveRecord::Migration[8.0]
  def change
    create_table :event_posts, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :event_id, null: false
      t.uuid :user_id, null: false
      t.text :content
      t.string :status, default: 'active', null: false
      t.datetime :deleted_at
      t.timestamps

      t.index :event_id
      t.index :user_id
      t.index :status
      t.index :deleted_at
      t.index [:event_id, :created_at]
      t.index [:user_id, :created_at]
      t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'hidden'::character varying, 'deleted'::character varying]::text[])", name: "check_event_post_status"
    end

    add_foreign_key :event_posts, :events, on_delete: :cascade
    add_foreign_key :event_posts, :users, on_delete: :cascade
  end
end


