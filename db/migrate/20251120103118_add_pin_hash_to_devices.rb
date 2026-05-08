class AddPinHashToDevices < ActiveRecord::Migration[8.0]
  def change
    add_column :devices, :pin_hash, :string
  end
end
