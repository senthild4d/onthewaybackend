class CreateEventBoosts < ActiveRecord::Migration[8.0]
  def change
    create_table :event_boosts, id: :uuid do |t|
      t.references :event, null: false, foreign_key: true, type: :uuid
      t.references :created_by, null: false, foreign_key: { to_table: :users }, type: :uuid

      # Performance Goal
      # Options: page_views, link_clicks, daily_reach
      t.string :performance_goal, null: false, default: 'page_views'

      # Schedule
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :timezone, default: 'UTC'

      # Audience Targeting - Age Range
      t.integer :target_age_min, default: 18
      t.integer :target_age_max, default: 65

      # Audience Targeting - Gender
      # Options: all, male, female, other
      t.string :target_gender, default: 'all'

      # Geo-Fencing / Location Targeting
      t.string :geo_fence_address
      t.string :geo_fence_city
      t.string :geo_fence_region
      t.string :geo_fence_country
      t.decimal :geo_fence_latitude, precision: 10, scale: 6
      t.decimal :geo_fence_longitude, precision: 10, scale: 6
      t.decimal :geo_fence_radius_km, precision: 8, scale: 2, default: 10.0  # Radius in kilometers

      # Budget and Spend
      t.decimal :daily_budget, precision: 10, scale: 2
      t.decimal :total_budget, precision: 10, scale: 2
      t.string :currency, default: 'USD'
      t.decimal :amount_spent, precision: 10, scale: 2, default: 0.0

      # Performance Metrics
      t.integer :impressions_count, default: 0
      t.integer :page_views_count, default: 0
      t.integer :link_clicks_count, default: 0
      t.integer :unique_reach_count, default: 0

      # Status
      # Options: draft, pending_review, active, paused, completed, rejected, cancelled
      t.string :status, null: false, default: 'draft'
      t.datetime :approved_at
      t.datetime :paused_at
      t.datetime :completed_at
      t.datetime :rejected_at
      t.datetime :cancelled_at
      t.string :rejection_reason

      # Additional Settings
      t.text :notes
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :event_boosts, :status
    add_index :event_boosts, :performance_goal
    add_index :event_boosts, [:starts_at, :ends_at]
    add_index :event_boosts, :target_gender
    add_index :event_boosts, [:target_age_min, :target_age_max]
    add_index :event_boosts, [:geo_fence_latitude, :geo_fence_longitude], name: 'index_event_boosts_on_geo_fence_coords'

    # Constraint for performance goal values
    add_check_constraint :event_boosts, 
      "performance_goal IN ('page_views', 'link_clicks', 'daily_reach')",
      name: 'event_boosts_performance_goal_check'

    # Constraint for target gender values
    add_check_constraint :event_boosts,
      "target_gender IN ('all', 'male', 'female', 'other')",
      name: 'event_boosts_target_gender_check'

    # Constraint for status values
    add_check_constraint :event_boosts,
      "status IN ('draft', 'pending_review', 'active', 'paused', 'completed', 'rejected', 'cancelled')",
      name: 'event_boosts_status_check'

    # Constraint for age range
    add_check_constraint :event_boosts,
      "target_age_min >= 0 AND target_age_min <= 120 AND target_age_max >= 0 AND target_age_max <= 120 AND target_age_min <= target_age_max",
      name: 'event_boosts_age_range_check'

    # Constraint for geo fence radius
    add_check_constraint :event_boosts,
      "geo_fence_radius_km IS NULL OR (geo_fence_radius_km > 0 AND geo_fence_radius_km <= 500)",
      name: 'event_boosts_geo_fence_radius_check'
  end
end

