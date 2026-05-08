class CreatePropertyViewings < ActiveRecord::Migration[8.0]
  def change
    create_table :property_viewings, id: :uuid do |t|
      t.uuid :property_id, null: false
      t.uuid :user_id, null: false

      t.string :status, default: 'requested', null: false # requested|confirmed|cancelled|completed
      t.datetime :requested_for
      t.text :message

      t.string :contact_phone
      t.string :contact_email

      t.uuid :handled_by_id
      t.datetime :handled_at
      t.text :admin_notes

      t.timestamps
    end

    add_index :property_viewings, :property_id
    add_index :property_viewings, :user_id
    add_index :property_viewings, :status
    add_index :property_viewings, :requested_for
    add_index :property_viewings, :handled_by_id

    add_foreign_key :property_viewings, :properties, on_delete: :cascade
    add_foreign_key :property_viewings, :users, on_delete: :cascade
    add_foreign_key :property_viewings, :users, column: :handled_by_id, on_delete: :nullify

    add_check_constraint :property_viewings,
                         "status IN ('requested','confirmed','cancelled','completed')",
                         name: 'check_property_viewings_status'
  end
end

