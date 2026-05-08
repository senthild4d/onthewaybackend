class CreateUserBlocksAndReports < ActiveRecord::Migration[8.0]
  def change
    create_table :user_blocks, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :blocker_id, null: false
      t.uuid :blocked_id, null: false
      t.timestamps

      t.index [:blocker_id, :blocked_id], unique: true, name: "index_user_blocks_blocker_blocked_unique"
      t.index :blocker_id
      t.index :blocked_id
    end

    add_foreign_key :user_blocks, :users, column: :blocker_id, on_delete: :cascade
    add_foreign_key :user_blocks, :users, column: :blocked_id, on_delete: :cascade

    create_table :user_reports, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :reporter_id, null: false
      t.uuid :reported_id, null: false
      t.string :reason, null: false
      t.text :description
      t.string :status, default: 'pending', null: false
      t.uuid :reviewed_by_id
      t.text :admin_notes
      t.datetime :reviewed_at
      t.timestamps

      t.index :reporter_id
      t.index :reported_id
      t.index :status
      t.index [:reporter_id, :reported_id], name: "index_user_reports_reporter_reported"
      t.check_constraint "reason::text = ANY (ARRAY['spam'::character varying, 'harassment'::character varying, 'inappropriate'::character varying, 'fake_account'::character varying, 'other'::character varying]::text[])", name: "check_user_report_reason"
      t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'reviewed'::character varying, 'resolved'::character varying, 'dismissed'::character varying]::text[])", name: "check_user_report_status"
    end

    add_foreign_key :user_reports, :users, column: :reporter_id, on_delete: :cascade
    add_foreign_key :user_reports, :users, column: :reported_id, on_delete: :cascade
    add_foreign_key :user_reports, :users, column: :reviewed_by_id, on_delete: :nullify
  end
end

