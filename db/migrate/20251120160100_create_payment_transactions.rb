class CreatePaymentTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :payment_transactions, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :wallet_id, null: false
      t.uuid :user_id, null: false
      t.string :transaction_type, null: false
      t.string :status, default: 'pending', null: false
      t.decimal :amount, precision: 20, scale: 8, null: false
      t.string :currency, default: 'USD', null: false
      t.string :payment_method, null: false
      t.string :payment_provider
      t.string :provider_transaction_id
      t.text :provider_response
      t.string :reference_type
      t.uuid :reference_id
      t.text :description
      t.text :metadata
      t.decimal :fee, precision: 20, scale: 8, default: 0.0, null: false
      t.decimal :net_amount, precision: 20, scale: 8, null: false
      t.datetime :processed_at
      t.timestamps

      t.index :wallet_id
      t.index :user_id
      t.index :transaction_type
      t.index :status
      t.index :payment_method
      t.index :payment_provider
      t.index :provider_transaction_id
      t.index [:reference_type, :reference_id]
      t.index :created_at
      t.check_constraint "amount > 0", name: "check_payment_transaction_amount_positive"
      t.check_constraint "fee >= 0", name: "check_payment_transaction_fee_non_negative"
      t.check_constraint "transaction_type::text = ANY (ARRAY['deposit'::character varying, 'withdrawal'::character varying, 'payment'::character varying, 'refund'::character varying, 'transfer'::character varying]::text[])", name: "check_payment_transaction_type"
      t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'processing'::character varying, 'completed'::character varying, 'failed'::character varying, 'cancelled'::character varying, 'refunded'::character varying]::text[])", name: "check_payment_transaction_status"
      t.check_constraint "payment_method::text = ANY (ARRAY['credit_card'::character varying, 'debit_card'::character varying, 'bank_transfer'::character varying, 'crypto'::character varying, 'paypal'::character varying, 'apple_pay'::character varying, 'google_pay'::character varying, 'other'::character varying]::text[])", name: "check_payment_transaction_method"
    end

    add_foreign_key :payment_transactions, :wallets, on_delete: :restrict
    add_foreign_key :payment_transactions, :users, on_delete: :restrict
  end
end

