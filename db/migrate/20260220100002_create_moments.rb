# Moments: live-only clips kept on platform. No upload; no edit; no platform music.
# Audience: public | followers. Disappearing: 24h, 72h, 1w, 1m, 3m, 6m, 1y, or none (delete only; no archive).
# See docs/STREAM_AND_MOMENTS_SPEC.md
class CreateMoments < ActiveRecord::Migration[8.0]
  def change
    create_table :moments, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.references :venue, null: true, type: :uuid, foreign_key: true
      t.references :event, null: true, type: :uuid, foreign_key: true
      t.string :audience, default: 'public', null: false
      t.string :disappearing_duration, default: 'none', null: false
      t.datetime :expires_at
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :moments, [:user_id, :created_at]
    add_index :moments, :expires_at, where: 'expires_at IS NOT NULL'
    add_index :moments, :deleted_at, where: 'deleted_at IS NULL'
    add_check_constraint :moments,
      "audience IN ('public', 'followers')",
      name: 'check_moments_audience'
    add_check_constraint :moments,
      "disappearing_duration IN ('24h', '72h', '1_week', '1_month', '3_months', '6_months', '1_year', 'none')",
      name: 'check_moments_disappearing_duration'
  end
end
