# Live streams (Cloudflare): 1 hour per venue per day.
# Stream views: one view per user; cap 30–90s; stream disappears from feed after view.
# See docs/STREAM_AND_MOMENTS_SPEC.md
class CreateLiveStreamsAndStreamViews < ActiveRecord::Migration[8.0]
  def change
    create_table :live_streams, id: :uuid do |t|
      t.references :venue, null: false, type: :uuid, foreign_key: true
      t.references :event, null: true, type: :uuid, foreign_key: true
      t.string :cloudflare_live_input_uid, null: false, index: { unique: true }
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.integer :duration_seconds
      t.string :status, default: 'live', null: false
      t.timestamps
    end
    add_index :live_streams, [:venue_id, :started_at]
    add_check_constraint :live_streams, "status IN ('live', 'ended', 'deleted')", name: 'check_live_streams_status'

    create_table :stream_views, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.references :live_stream, null: false, type: :uuid, foreign_key: true
      t.integer :watched_seconds, null: false
      t.datetime :viewed_at, null: false
      t.timestamps
    end
    add_index :stream_views, [:user_id, :live_stream_id], unique: true
  end
end
