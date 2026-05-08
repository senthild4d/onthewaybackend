# frozen_string_literal: true

class CreateVenuePrPartnerships < ActiveRecord::Migration[7.1]
  def change
    create_table :venue_pr_partnerships, id: :uuid do |t|
      t.references :venue, type: :uuid, null: false, foreign_key: true
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.string :role, default: 'master_pr', null: false
      t.string :status, default: 'active', null: false
      t.datetime :ended_at

      t.timestamps
    end

    add_index :venue_pr_partnerships, :venue_id,
              unique: true,
              where: "status = 'active'",
              name: 'index_venue_pr_partnerships_active_venue'
    add_index :venue_pr_partnerships, [:user_id, :status],
              name: 'index_venue_pr_partnerships_on_user_and_status'
  end
end
