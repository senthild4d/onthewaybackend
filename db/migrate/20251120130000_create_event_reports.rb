class CreateEventReports < ActiveRecord::Migration[8.0]
  def change
    create_table :event_reports, id: :uuid do |t|
      t.references :event, null: false, foreign_key: true, type: :uuid, index: true
      t.references :reporter, null: false, foreign_key: { to_table: :users }, type: :uuid, index: true
      t.string :reason, null: false
      t.text :description
      t.string :status, default: 'pending', null: false
      t.references :reviewed_by, foreign_key: { to_table: :users }, type: :uuid, index: false
      t.text :admin_notes
      t.datetime :reviewed_at
      
      t.timestamps
    end
    
    add_index :event_reports, :status
    add_index :event_reports, [:event_id, :reporter_id], unique: true, name: 'index_event_reports_event_reporter_unique'
    add_check_constraint :event_reports, "status IN ('pending', 'reviewed', 'resolved', 'dismissed')", name: 'check_event_report_status'
    add_check_constraint :event_reports, "reason IN ('spam', 'inappropriate', 'misleading', 'duplicate', 'violence', 'harassment', 'other')", name: 'check_event_report_reason'
  end
end

