class CreateEventArtists < ActiveRecord::Migration[8.0]
  def change
    create_table :event_artists, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :event_id, null: false
      t.uuid :artist_id, null: false
      t.datetime :scheduled_start_at, null: false
      t.datetime :scheduled_end_at, null: false
      t.string :timezone, default: 'UTC', null: false
      t.integer :display_order, default: 0, null: false
      t.text :description
      t.string :status, default: 'confirmed', null: false
      t.timestamps

      t.index [:event_id, :artist_id], unique: true, name: 'index_event_artists_event_artist_unique'
      t.index :event_id
      t.index :artist_id
      t.index :scheduled_start_at
      t.index :display_order
      t.index :status
      t.check_constraint "scheduled_end_at > scheduled_start_at", name: "check_event_artist_schedule"
      t.check_constraint "status::text = ANY (ARRAY['confirmed'::character varying, 'pending'::character varying, 'cancelled'::character varying]::text[])", name: "check_event_artist_status"
    end

    add_foreign_key :event_artists, :events, on_delete: :cascade
    add_foreign_key :event_artists, :users, column: :artist_id, on_delete: :cascade
  end
end

