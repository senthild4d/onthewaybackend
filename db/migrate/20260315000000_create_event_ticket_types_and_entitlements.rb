# frozen_string_literal: true

class CreateEventTicketTypesAndEntitlements < ActiveRecord::Migration[8.0]
  def change
    create_table :event_ticket_types, id: :uuid do |t|
      t.references :event, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.decimal :price, precision: 10, scale: 2, null: false, default: 0
      t.string :currency, limit: 8
      t.integer :quantity_total, null: false, default: 0
      t.integer :quantity_sold, null: false, default: 0
      t.integer :display_order, null: false, default: 0
      t.timestamps
    end

    add_index :event_ticket_types, [:event_id, :display_order], name: 'index_event_ticket_types_on_event_and_order'

    create_table :booking_ticket_lines, id: :uuid do |t|
      t.references :booking, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :event_ticket_type, type: :uuid, null: false, foreign_key: { on_delete: :restrict }
      t.integer :quantity, null: false
      t.decimal :unit_price, precision: 10, scale: 2, null: false
      t.decimal :line_total, precision: 10, scale: 2, null: false
      t.timestamps
    end

    # booking_id / event_ticket_type_id indexes come from t.references (default index: true)

    create_table :ticket_entitlements, id: :uuid do |t|
      t.references :booking, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :event_ticket_type, type: :uuid, null: false, foreign_key: { on_delete: :restrict }
        t.references :purchaser, type: :uuid, null: false, foreign_key: { to_table: :users }
        t.references :holder, type: :uuid, null: true, foreign_key: { to_table: :users }
      t.string :qr_token, null: false
      t.string :invite_token
      t.string :invited_email
      t.datetime :invited_at
      t.string :status, null: false, default: 'pending_payment'
      t.datetime :checked_in_at
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :ticket_entitlements, :qr_token, unique: true
    add_index :ticket_entitlements, :invite_token, unique: true, where: 'invite_token IS NOT NULL'
    # booking_id index already created by t.references :booking above
    add_index :ticket_entitlements, [:booking_id, :position]

    add_check_constraint :event_ticket_types, 'quantity_total >= 0', name: 'check_event_ticket_types_qty_total'
    add_check_constraint :event_ticket_types, 'quantity_sold >= 0', name: 'check_event_ticket_types_qty_sold'
    add_check_constraint :event_ticket_types, 'quantity_sold <= quantity_total', name: 'check_event_ticket_types_sold_lte_total'
    add_check_constraint :booking_ticket_lines, 'quantity > 0', name: 'check_booking_ticket_lines_qty'
    add_check_constraint :ticket_entitlements,
      "status IN ('pending_payment', 'active', 'checked_in', 'canceled')",
      name: 'check_ticket_entitlements_status'
  end
end
