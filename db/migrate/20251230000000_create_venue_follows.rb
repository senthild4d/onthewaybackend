class CreateVenueFollows < ActiveRecord::Migration[8.0]
  def change
    create_table :venue_follows, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :user_id, null: false
      t.uuid :venue_id, null: false
      t.timestamps

      t.index [:user_id, :venue_id], unique: true, name: 'index_venue_follows_user_venue_unique'
      t.index :user_id
      t.index :venue_id
    end

    add_foreign_key :venue_follows, :users, column: :user_id, on_delete: :cascade
    add_foreign_key :venue_follows, :venues, column: :venue_id, on_delete: :cascade
  end
end

