class AddFcmTokenToDevices < ActiveRecord::Migration[8.0]
  def change
    add_column :devices, :fcm_token, :string
    add_index :devices, :fcm_token, where: "fcm_token IS NOT NULL"
  end
end
