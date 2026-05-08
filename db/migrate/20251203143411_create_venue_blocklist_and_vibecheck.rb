class CreateVenueBlocklistAndVibecheck < ActiveRecord::Migration[8.0]
  def change
    # Venue Blocklist - Block users from specific venues
    create_table :venue_blocklists, id: :uuid do |t|
      t.uuid :venue_id, null: false
      t.uuid :user_id, null: false
      t.uuid :blocked_by_id, null: false
      t.string :reason, null: false
      t.text :description
      t.string :incident_type # 'no_show', 'late_cancellation', 'behavior', 'fraud', 'other'
      t.uuid :related_event_id
      t.uuid :related_booking_id
      t.datetime :blocked_until # Temporary block expiry
      t.boolean :is_permanent, default: false, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end

    add_index :venue_blocklists, :venue_id
    add_index :venue_blocklists, :user_id
    add_index :venue_blocklists, [:venue_id, :user_id]
    add_index :venue_blocklists, :blocked_by_id
    add_index :venue_blocklists, :is_permanent
    add_foreign_key :venue_blocklists, :venues, on_delete: :cascade
    add_foreign_key :venue_blocklists, :users, column: :user_id, on_delete: :cascade
    add_foreign_key :venue_blocklists, :users, column: :blocked_by_id, on_delete: :nullify
    add_foreign_key :venue_blocklists, :events, column: :related_event_id, on_delete: :nullify
    add_foreign_key :venue_blocklists, :bookings, column: :related_booking_id, on_delete: :nullify

    # Add cancellation confirmation workflow to bookings
    add_column :bookings, :cancellation_requested, :boolean, default: false, null: false
    add_column :bookings, :cancellation_requested_at, :datetime
    add_column :bookings, :cancellation_reason, :text
    add_column :bookings, :cancellation_approved, :boolean
    add_column :bookings, :cancellation_approved_by_id, :uuid
    add_column :bookings, :cancellation_approved_at, :datetime
    add_column :bookings, :cancellation_rejected_reason, :text
    
    add_index :bookings, :cancellation_requested
    add_index :bookings, :cancellation_approved
    add_foreign_key :bookings, :users, column: :cancellation_approved_by_id, on_delete: :nullify

    # VibeCheck - Post-event rating/review system
    create_table :vibe_checks, id: :uuid do |t|
      t.uuid :event_id, null: false
      t.uuid :user_id, null: false
      t.uuid :booking_id
      t.integer :overall_rating, null: false # 1-5
      t.integer :atmosphere_rating # 1-5
      t.integer :music_rating # 1-5
      t.integer :crowd_rating # 1-5
      t.integer :service_rating # 1-5
      t.integer :value_rating # 1-5
      t.text :review
      t.text :highlights # What was good
      t.text :lowlights # What could improve
      t.boolean :would_return, default: true
      t.boolean :would_recommend, default: true
      t.string :status, default: 'published', null: false # 'published', 'hidden', 'flagged'
      t.integer :helpful_count, default: 0
      t.timestamps
    end

    add_index :vibe_checks, :event_id
    add_index :vibe_checks, :user_id
    add_index :vibe_checks, [:event_id, :user_id], unique: true
    add_index :vibe_checks, :booking_id
    add_index :vibe_checks, :overall_rating
    add_index :vibe_checks, :status
    add_index :vibe_checks, :created_at
    add_foreign_key :vibe_checks, :events, on_delete: :cascade
    add_foreign_key :vibe_checks, :users, on_delete: :cascade
    add_foreign_key :vibe_checks, :bookings, on_delete: :nullify

    # Check constraints
    add_check_constraint :venue_blocklists,
      "incident_type IS NULL OR incident_type IN ('no_show', 'late_cancellation', 'behavior', 'fraud', 'other')",
      name: 'check_venue_blocklist_incident_type'

    add_check_constraint :vibe_checks,
      "overall_rating >= 1 AND overall_rating <= 5",
      name: 'check_vibecheck_overall_rating'

    add_check_constraint :vibe_checks,
      "atmosphere_rating IS NULL OR (atmosphere_rating >= 1 AND atmosphere_rating <= 5)",
      name: 'check_vibecheck_atmosphere_rating'

    add_check_constraint :vibe_checks,
      "music_rating IS NULL OR (music_rating >= 1 AND music_rating <= 5)",
      name: 'check_vibecheck_music_rating'

    add_check_constraint :vibe_checks,
      "crowd_rating IS NULL OR (crowd_rating >= 1 AND crowd_rating <= 5)",
      name: 'check_vibecheck_crowd_rating'

    add_check_constraint :vibe_checks,
      "service_rating IS NULL OR (service_rating >= 1 AND service_rating <= 5)",
      name: 'check_vibecheck_service_rating'

    add_check_constraint :vibe_checks,
      "value_rating IS NULL OR (value_rating >= 1 AND value_rating <= 5)",
      name: 'check_vibecheck_value_rating'

    add_check_constraint :vibe_checks,
      "status IN ('published', 'hidden', 'flagged')",
      name: 'check_vibecheck_status'
  end
end

