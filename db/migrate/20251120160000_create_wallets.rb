class CreateWallets < ActiveRecord::Migration[8.0]
  def change
    create_table :wallets, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :user_id, null: false
      t.string :currency, default: 'USD', null: false
      t.decimal :balance, precision: 20, scale: 8, default: 0.0, null: false
      t.decimal :locked_balance, precision: 20, scale: 8, default: 0.0, null: false
      t.string :status, default: 'active', null: false
      t.timestamps

      t.index :user_id
      t.index [:user_id, :currency], unique: true, name: "index_wallets_user_currency_unique"
      t.index :status
      t.check_constraint "balance >= 0", name: "check_wallet_balance_non_negative"
      t.check_constraint "locked_balance >= 0", name: "check_wallet_locked_balance_non_negative"
      t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'suspended'::character varying, 'closed'::character varying]::text[])", name: "check_wallet_status"
    end

    add_foreign_key :wallets, :users, on_delete: :cascade
  end
end

