class CreateVenueInterests < ActiveRecord::Migration[8.0]
  def change
    create_table :venue_interests, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :user_id, null: false
      t.uuid :venue_id, null: false
      t.string :rsvp_status, default: 'yes', null: false
      t.integer :guest_count, default: 0, null: false
      t.text :notes
      t.datetime :responded_at
      t.timestamps

      t.index [:user_id, :venue_id], unique: true, name: 'index_venue_interests_user_venue_unique'
      t.index :user_id
      t.index :venue_id
      t.index :rsvp_status
      t.check_constraint "rsvp_status::text = ANY (ARRAY['yes'::character varying, 'no'::character varying, 'maybe'::character varying]::text[])", name: "check_venue_rsvp_status"
    end

    add_foreign_key :venue_interests, :users, on_delete: :cascade
    add_foreign_key :venue_interests, :venues, on_delete: :cascade
  end
end

