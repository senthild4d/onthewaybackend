class CreateEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :events, id: :uuid do |t|
      t.references :venue, null: false, foreign_key: true, type: :uuid
      t.string :title, null: false
      t.text :description
      t.string :category, limit: 50
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :timezone, default: 'UTC', null: false
      t.string :status, default: 'draft', null: false
      t.datetime :published_at
      t.datetime :live_at
      t.datetime :blocked_at
      t.references :blocked_by, foreign_key: { to_table: :users }, type: :uuid
      t.string :block_scope, limit: 20
      t.text :block_reason
      t.integer :age_restriction
      t.string :visibility, default: 'public', null: false
      
      t.timestamps
    end
    
    add_index :events, :status
    add_index :events, :starts_at
    add_index :events, :category
    add_index :events, :visibility
    add_index :events, [:status, :starts_at], name: 'index_events_status_starts_at'
    add_check_constraint :events, "status IN ('draft', 'published', 'canceled', 'completed')", name: 'check_event_status'
    add_check_constraint :events, "block_scope IS NULL OR block_scope IN ('sales', 'visibility', 'checkin', 'all')", name: 'check_event_block_scope'
    add_check_constraint :events, "visibility IN ('public', 'private', 'unlisted')", name: 'check_event_visibility'
    add_check_constraint :events, "ends_at > starts_at", name: 'check_event_dates'
    add_check_constraint :events, "age_restriction IS NULL OR (age_restriction >= 0 AND age_restriction <= 99)", name: 'check_event_age_restriction'
  end
end

