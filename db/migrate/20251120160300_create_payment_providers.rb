class CreatePaymentProviders < ActiveRecord::Migration[8.0]
  def change
    create_table :payment_providers, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :name, null: false
      t.string :provider_type, null: false
      t.string :status, default: 'active', null: false
      t.jsonb :credentials, default: {}, null: false
      t.jsonb :settings, default: {}, null: false
      t.boolean :is_default, default: false, null: false
      t.text :description
      t.timestamps

      t.index :name, unique: true
      t.index :provider_type
      t.index :status
      t.index :is_default
      t.check_constraint "provider_type::text = ANY (ARRAY['stripe'::character varying, 'paypal'::character varying, 'crypto'::character varying, 'bank'::character varying, 'apple_pay'::character varying, 'google_pay'::character varying, 'other'::character varying]::text[])", name: "check_payment_provider_type"
      t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'inactive'::character varying, 'maintenance'::character varying]::text[])", name: "check_payment_provider_status"
    end
  end
end

