class CreateCryptoWallets < ActiveRecord::Migration[8.0]
  def change
    create_table :crypto_wallets, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :user_id, null: false
      t.string :crypto_currency, null: false
      t.string :wallet_address, null: false
      t.string :wallet_type, default: 'external', null: false
      t.string :network
      t.string :status, default: 'active', null: false
      t.text :metadata
      t.timestamps

      t.index :user_id
      t.index [:user_id, :crypto_currency], name: "index_crypto_wallets_user_crypto"
      t.index :wallet_address
      t.index :status
      t.check_constraint "crypto_currency::text = ANY (ARRAY['BTC'::character varying, 'ETH'::character varying, 'USDT'::character varying, 'USDC'::character varying, 'SOL'::character varying, 'MATIC'::character varying, 'BNB'::character varying]::text[])", name: "check_crypto_wallet_currency"
      t.check_constraint "wallet_type::text = ANY (ARRAY['external'::character varying, 'internal'::character varying]::text[])", name: "check_crypto_wallet_type"
      t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'suspended'::character varying, 'archived'::character varying]::text[])", name: "check_crypto_wallet_status"
    end

    add_foreign_key :crypto_wallets, :users, on_delete: :cascade
  end
end

