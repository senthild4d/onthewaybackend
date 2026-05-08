class CreateUserDeactivations < ActiveRecord::Migration[8.0]
  def change
    create_table :user_deactivations, id: :uuid do |t|
      t.uuid :user_id, null: false
      t.string :reason
      t.text :additional_feedback
      t.datetime :deactivated_at, null: false
      t.datetime :reactivated_at
      t.string :reactivated_by # 'user' or 'admin' or user_id if admin
      t.text :reactivation_notes

      t.timestamps
    end

    add_index :user_deactivations, :user_id
    add_index :user_deactivations, :reason
    add_index :user_deactivations, :deactivated_at
    add_index :user_deactivations, :reactivated_at
    add_foreign_key :user_deactivations, :users, on_delete: :cascade
  end
end

