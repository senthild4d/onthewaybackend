class CreateDevices < ActiveRecord::Migration[8.0]
  def change
    create_table :devices, id: :uuid do |t|
      t.uuid :user_id, null: false
      t.string :device_uuid, null: false
      t.string :device_name
      t.string :device_type
      t.string :platform, null: false
      t.string :platform_version
      t.string :app_version
      t.boolean :biometric_enabled, default: false, null: false
      t.datetime :last_used_at
      t.string :token_hash, null: false
      t.string :status, default: 'active', null: false

      t.timestamps
    end

    add_index :devices, :user_id
    add_index :devices, :device_uuid
    add_index :devices, :token_hash, unique: true
    add_index :devices, :status
    add_index :devices, [:user_id, :device_uuid], unique: true
    add_foreign_key :devices, :users
  end
end
