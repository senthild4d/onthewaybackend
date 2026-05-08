# frozen_string_literal: true

class CreateSupportTickets < ActiveRecord::Migration[8.0]
  def change
    create_table :support_tickets, id: :uuid do |t|
      t.uuid :user_id, null: true
      t.string :related_type
      t.uuid :related_id
      t.string :reason, null: false
      t.string :status, null: false, default: 'open'
      t.string :priority, null: false, default: 'medium'
      t.text :custom_reason
      t.text :description
      t.uuid :assigned_to_id

      t.timestamps
    end

    add_index :support_tickets, :user_id
    add_index :support_tickets, [:related_type, :related_id]
    add_index :support_tickets, :reason
    add_index :support_tickets, :status
    add_index :support_tickets, :assigned_to_id
  end
end

