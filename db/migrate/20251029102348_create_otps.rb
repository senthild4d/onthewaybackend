class CreateOtps < ActiveRecord::Migration[8.0]
  def change
    create_table :otps, id: :uuid do |t|
      t.string :phone, null: false
      t.string :code, null: false
      t.datetime :expires_at, null: false
      t.boolean :verified, default: false, null: false
      t.references :user, type: :uuid, foreign_key: true
      t.integer :attempts, default: 0, null: false

      t.timestamps
    end

    add_index :otps, :phone
    add_index :otps, [:phone, :code]
    add_index :otps, :expires_at
  end
end
