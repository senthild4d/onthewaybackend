class CreatePaymentMethods < ActiveRecord::Migration[8.0]
  def change
    create_table :payment_methods, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :user_id, null: false
      t.string :payment_method_type, null: false
      t.string :provider, null: false
      t.string :provider_payment_method_id, null: false
      t.string :card_brand
      t.string :card_last4
      t.string :card_exp_month
      t.string :card_exp_year
      t.string :billing_name
      t.string :billing_email
      t.string :billing_phone
      t.jsonb :billing_address, default: {}
      t.jsonb :metadata, default: {}
      t.boolean :is_default, default: false, null: false
      t.string :status, default: 'active', null: false
      t.timestamps

      t.index :user_id
      t.index [:user_id, :provider, :provider_payment_method_id], unique: true, name: "index_payment_methods_user_provider_unique"
      t.index :payment_method_type
      t.index :provider
      t.index :status
      t.index :is_default
      t.check_constraint "payment_method_type::text = ANY (ARRAY['credit_card'::character varying, 'debit_card'::character varying, 'bank_account'::character varying, 'crypto_wallet'::character varying, 'paypal'::character varying, 'apple_pay'::character varying, 'google_pay'::character varying]::text[])", name: "check_payment_method_type"
      t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'inactive'::character varying, 'expired'::character varying]::text[])", name: "check_payment_method_status"
    end

    add_foreign_key :payment_methods, :users, on_delete: :cascade
  end
end


