# frozen_string_literal: true

class AddAttendanceModeAndPrCommissionToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :attendance_mode, :string, limit: 20, default: 'rsvp'
    add_column :events, :pr_commission_type, :string, limit: 20, comment: 'exclusive=2%, non_exclusive=5% (business-side fee)'

    add_check_constraint :events,
      "attendance_mode IS NULL OR attendance_mode IN ('rsvp', 'tickets')",
      name: 'check_event_attendance_mode'
    add_check_constraint :events,
      "pr_commission_type IS NULL OR pr_commission_type IN ('exclusive', 'non_exclusive')",
      name: 'check_event_pr_commission_type'
  end
end
