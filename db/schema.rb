# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_05_08_000010) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "active_storage_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.uuid "record_id", null: false
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "allergens", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "code", null: false
    t.string "label", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_allergens_on_code", unique: true
    t.index ["label"], name: "index_allergens_on_label"
  end

  create_table "artist_categories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "category_id", null: false
    t.string "source", default: "onboarding", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_artist_categories_on_category_id"
    t.index ["user_id", "category_id"], name: "index_artist_categories_on_user_id_and_category_id", unique: true
    t.index ["user_id"], name: "index_artist_categories_on_user_id"
  end

  create_table "categories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "categories_group_id", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.string "icon_key"
    t.integer "display_order", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["categories_group_id", "name"], name: "index_categories_on_categories_group_id_and_name", unique: true
    t.index ["display_order"], name: "index_categories_on_display_order"
    t.index ["slug"], name: "index_categories_on_slug", unique: true
  end

  create_table "categories_groups", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.text "description"
    t.integer "display_order", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["display_order"], name: "index_categories_groups_on_display_order"
    t.index ["slug"], name: "index_categories_groups_on_slug", unique: true
  end

  create_table "crypto_wallets", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "crypto_currency", null: false
    t.string "wallet_address", null: false
    t.string "wallet_type", default: "external", null: false
    t.string "network"
    t.string "status", default: "active", null: false
    t.text "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_crypto_wallets_on_status"
    t.index ["user_id", "crypto_currency"], name: "index_crypto_wallets_user_crypto"
    t.index ["user_id"], name: "index_crypto_wallets_on_user_id"
    t.index ["wallet_address"], name: "index_crypto_wallets_on_wallet_address"
    t.check_constraint "crypto_currency::text = ANY (ARRAY['BTC'::character varying::text, 'ETH'::character varying::text, 'USDT'::character varying::text, 'USDC'::character varying::text, 'SOL'::character varying::text, 'MATIC'::character varying::text, 'BNB'::character varying::text])", name: "check_crypto_wallet_currency"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'suspended'::character varying::text, 'archived'::character varying::text])", name: "check_crypto_wallet_status"
    t.check_constraint "wallet_type::text = ANY (ARRAY['external'::character varying::text, 'internal'::character varying::text])", name: "check_crypto_wallet_type"
  end

  create_table "devices", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "device_uuid", null: false
    t.string "device_name"
    t.string "device_type"
    t.string "platform", null: false
    t.string "platform_version"
    t.string "app_version"
    t.boolean "biometric_enabled", default: false, null: false
    t.datetime "last_used_at"
    t.string "token_hash", null: false
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "pin_hash"
    t.string "fcm_token"
    t.index ["device_uuid"], name: "index_devices_on_device_uuid", unique: true
    t.index ["fcm_token"], name: "index_devices_on_fcm_token", where: "(fcm_token IS NOT NULL)"
    t.index ["status"], name: "index_devices_on_status"
    t.index ["token_hash"], name: "index_devices_on_token_hash", unique: true
    t.index ["user_id", "device_uuid"], name: "index_devices_on_user_id_and_device_uuid", unique: true
    t.index ["user_id"], name: "index_devices_on_user_id"
  end

  create_table "legal_documents", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["kind"], name: "index_legal_documents_on_kind", unique: true
  end

  create_table "notifications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "notification_type", null: false
    t.string "title", null: false
    t.text "message", null: false
    t.jsonb "metadata", default: {}, null: false
    t.boolean "read", default: false, null: false
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_notifications_on_created_at"
    t.index ["notification_type"], name: "index_notifications_on_notification_type"
    t.index ["read"], name: "index_notifications_on_read"
    t.index ["user_id", "read"], name: "index_notifications_on_user_id_and_read"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "otps", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "phone"
    t.string "code", null: false
    t.datetime "expires_at", null: false
    t.boolean "verified", default: false, null: false
    t.uuid "user_id"
    t.integer "attempts", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email"
    t.index ["email", "code"], name: "index_otps_on_email_and_code"
    t.index ["expires_at"], name: "index_otps_on_expires_at"
    t.index ["phone", "code"], name: "index_otps_on_phone_and_code"
    t.index ["phone"], name: "index_otps_on_phone"
    t.index ["user_id"], name: "index_otps_on_user_id"
    t.check_constraint "phone IS NOT NULL OR email IS NOT NULL", name: "check_phone_or_email"
  end

  create_table "payment_methods", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "payment_method_type", null: false
    t.string "provider", null: false
    t.string "provider_payment_method_id", null: false
    t.string "card_brand"
    t.string "card_last4"
    t.string "card_exp_month"
    t.string "card_exp_year"
    t.string "billing_name"
    t.string "billing_email"
    t.string "billing_phone"
    t.jsonb "billing_address", default: {}
    t.jsonb "metadata", default: {}
    t.boolean "is_default", default: false, null: false
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_default"], name: "index_payment_methods_on_is_default"
    t.index ["payment_method_type"], name: "index_payment_methods_on_payment_method_type"
    t.index ["provider"], name: "index_payment_methods_on_provider"
    t.index ["status"], name: "index_payment_methods_on_status"
    t.index ["user_id", "provider", "provider_payment_method_id"], name: "index_payment_methods_user_provider_unique", unique: true
    t.index ["user_id"], name: "index_payment_methods_on_user_id"
    t.check_constraint "payment_method_type::text = ANY (ARRAY['credit_card'::character varying::text, 'debit_card'::character varying::text, 'bank_account'::character varying::text, 'crypto_wallet'::character varying::text, 'paypal'::character varying::text, 'apple_pay'::character varying::text, 'google_pay'::character varying::text])", name: "check_payment_method_type"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'inactive'::character varying::text, 'expired'::character varying::text])", name: "check_payment_method_status"
  end

  create_table "payment_providers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "provider_type", null: false
    t.string "status", default: "active", null: false
    t.jsonb "credentials", default: {}, null: false
    t.jsonb "settings", default: {}, null: false
    t.boolean "is_default", default: false, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_default"], name: "index_payment_providers_on_is_default"
    t.index ["name"], name: "index_payment_providers_on_name", unique: true
    t.index ["provider_type"], name: "index_payment_providers_on_provider_type"
    t.index ["status"], name: "index_payment_providers_on_status"
    t.check_constraint "provider_type::text = ANY (ARRAY['stripe'::character varying::text, 'paypal'::character varying::text, 'crypto'::character varying::text, 'bank'::character varying::text, 'apple_pay'::character varying::text, 'google_pay'::character varying::text, 'other'::character varying::text])", name: "check_payment_provider_type"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'inactive'::character varying::text, 'maintenance'::character varying::text])", name: "check_payment_provider_status"
  end

  create_table "payment_transactions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "wallet_id", null: false
    t.uuid "user_id", null: false
    t.string "transaction_type", null: false
    t.string "status", default: "pending", null: false
    t.decimal "amount", precision: 20, scale: 8, null: false
    t.string "currency", default: "USD", null: false
    t.string "payment_method", null: false
    t.string "payment_provider"
    t.string "provider_transaction_id"
    t.text "provider_response"
    t.string "reference_type"
    t.uuid "reference_id"
    t.text "description"
    t.text "metadata"
    t.decimal "fee", precision: 20, scale: 8, default: "0.0", null: false
    t.decimal "net_amount", precision: 20, scale: 8, null: false
    t.datetime "processed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_payment_transactions_on_created_at"
    t.index ["payment_method"], name: "index_payment_transactions_on_payment_method"
    t.index ["payment_provider"], name: "index_payment_transactions_on_payment_provider"
    t.index ["provider_transaction_id"], name: "index_payment_transactions_on_provider_transaction_id"
    t.index ["reference_type", "reference_id"], name: "index_payment_transactions_on_reference_type_and_reference_id"
    t.index ["status"], name: "index_payment_transactions_on_status"
    t.index ["transaction_type"], name: "index_payment_transactions_on_transaction_type"
    t.index ["user_id"], name: "index_payment_transactions_on_user_id"
    t.index ["wallet_id"], name: "index_payment_transactions_on_wallet_id"
    t.check_constraint "amount > 0::numeric", name: "check_payment_transaction_amount_positive"
    t.check_constraint "fee >= 0::numeric", name: "check_payment_transaction_fee_non_negative"
    t.check_constraint "payment_method::text = ANY (ARRAY['credit_card'::character varying::text, 'debit_card'::character varying::text, 'bank_transfer'::character varying::text, 'crypto'::character varying::text, 'paypal'::character varying::text, 'apple_pay'::character varying::text, 'google_pay'::character varying::text, 'other'::character varying::text])", name: "check_payment_transaction_method"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'processing'::character varying::text, 'completed'::character varying::text, 'failed'::character varying::text, 'cancelled'::character varying::text, 'refunded'::character varying::text])", name: "check_payment_transaction_status"
    t.check_constraint "transaction_type::text = ANY (ARRAY['deposit'::character varying::text, 'withdrawal'::character varying::text, 'payment'::character varying::text, 'refund'::character varying::text, 'transfer'::character varying::text])", name: "check_payment_transaction_type"
  end

  create_table "properties", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "owner_id", null: false
    t.string "title", null: false
    t.text "description"
    t.string "property_type"
    t.integer "bedrooms"
    t.integer "bathrooms"
    t.decimal "area_sqft", precision: 12, scale: 2
    t.string "address1"
    t.string "address2"
    t.string "city"
    t.string "region"
    t.string "postal_code"
    t.string "country"
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "longitude", precision: 10, scale: 7
    t.decimal "price", precision: 12, scale: 2
    t.string "currency", default: "USD", null: false
    t.string "approval_status", default: "draft", null: false
    t.datetime "submitted_at"
    t.uuid "approved_by_id"
    t.datetime "approved_at"
    t.uuid "rejected_by_id"
    t.datetime "rejected_at"
    t.text "rejection_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approval_status"], name: "index_properties_on_approval_status"
    t.index ["latitude", "longitude"], name: "index_properties_on_latitude_and_longitude"
    t.index ["owner_id"], name: "index_properties_on_owner_id"
    t.check_constraint "approval_status::text = ANY (ARRAY['draft'::character varying, 'pending_review'::character varying, 'approved'::character varying, 'rejected'::character varying, 'archived'::character varying]::text[])", name: "check_properties_approval_status"
    t.check_constraint "latitude IS NULL OR latitude >= '-90'::integer::numeric AND latitude <= 90::numeric", name: "check_properties_latitude"
    t.check_constraint "longitude IS NULL OR longitude >= '-180'::integer::numeric AND longitude <= 180::numeric", name: "check_properties_longitude"
    t.check_constraint "price IS NULL OR price >= 0::numeric", name: "check_properties_price_non_negative"
  end

  create_table "split_qr_codes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "food_bar_order_id", null: false
    t.string "qr_token", null: false
    t.integer "max_participants"
    t.integer "current_participants", default: 1, null: false
    t.string "status", default: "active", null: false
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["food_bar_order_id"], name: "index_split_qr_codes_on_food_bar_order_id"
    t.index ["qr_token"], name: "index_split_qr_codes_on_qr_token", unique: true
    t.index ["status"], name: "index_split_qr_codes_on_status"
    t.check_constraint "current_participants <= max_participants OR max_participants IS NULL", name: "check_split_qr_participants"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'completed'::character varying::text, 'expired'::character varying::text])", name: "check_split_qr_code_status"
  end

  create_table "support_tickets", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id"
    t.string "related_type"
    t.uuid "related_id"
    t.string "reason", null: false
    t.string "status", default: "open", null: false
    t.string "priority", default: "medium", null: false
    t.text "custom_reason"
    t.text "description"
    t.uuid "assigned_to_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assigned_to_id"], name: "index_support_tickets_on_assigned_to_id"
    t.index ["reason"], name: "index_support_tickets_on_reason"
    t.index ["related_type", "related_id"], name: "index_support_tickets_on_related_type_and_related_id"
    t.index ["status"], name: "index_support_tickets_on_status"
    t.index ["user_id"], name: "index_support_tickets_on_user_id"
  end

  create_table "user_blocks", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blocker_id", null: false
    t.uuid "blocked_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["blocked_id"], name: "index_user_blocks_on_blocked_id"
    t.index ["blocker_id", "blocked_id"], name: "index_user_blocks_blocker_blocked_unique", unique: true
    t.index ["blocker_id"], name: "index_user_blocks_on_blocker_id"
  end

  create_table "user_deactivations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "reason"
    t.text "additional_feedback"
    t.datetime "deactivated_at", null: false
    t.datetime "reactivated_at"
    t.string "reactivated_by"
    t.text "reactivation_notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deactivated_at"], name: "index_user_deactivations_on_deactivated_at"
    t.index ["reactivated_at"], name: "index_user_deactivations_on_reactivated_at"
    t.index ["reason"], name: "index_user_deactivations_on_reason"
    t.index ["user_id"], name: "index_user_deactivations_on_user_id"
  end

  create_table "user_reports", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "reporter_id", null: false
    t.uuid "reported_id", null: false
    t.string "reason", null: false
    t.text "description"
    t.string "status", default: "pending", null: false
    t.uuid "reviewed_by_id"
    t.text "admin_notes"
    t.datetime "reviewed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reported_id"], name: "index_user_reports_on_reported_id"
    t.index ["reporter_id", "reported_id"], name: "index_user_reports_reporter_reported"
    t.index ["reporter_id"], name: "index_user_reports_on_reporter_id"
    t.index ["status"], name: "index_user_reports_on_status"
    t.check_constraint "reason::text = ANY (ARRAY['spam'::character varying::text, 'harassment'::character varying::text, 'inappropriate'::character varying::text, 'fake_account'::character varying::text, 'other'::character varying::text])", name: "check_user_report_reason"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'reviewed'::character varying::text, 'resolved'::character varying::text, 'dismissed'::character varying::text])", name: "check_user_report_status"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "email"
    t.string "phone", limit: 20
    t.string "password_digest"
    t.string "name"
    t.string "role", default: "consumer", null: false
    t.string "status", default: "active", null: false
    t.jsonb "preferences", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "current_location", default: {}, null: false
    t.string "username"
    t.date "date_of_birth"
    t.string "profile_picture_url"
    t.text "bio"
    t.jsonb "support_countries", default: [], null: false, comment: "Country codes (e.g. UK, US) this support user can moderate"
    t.index ["created_at"], name: "index_users_on_created_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["phone"], name: "index_users_on_phone", unique: true, where: "(phone IS NOT NULL)"
    t.index ["role"], name: "index_users_on_role"
    t.index ["status"], name: "index_users_on_status"
    t.index ["username"], name: "index_users_on_username", unique: true, where: "(username IS NOT NULL)"
    t.check_constraint "email::text ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}$'::text", name: "check_email_format"
    t.check_constraint "phone IS NOT NULL OR email IS NOT NULL", name: "check_user_phone_or_email"
    t.check_constraint "role::text = ANY (ARRAY['user'::character varying, 'owner'::character varying, 'support'::character varying, 'admin'::character varying]::text[])", name: "check_role"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'disabled'::character varying::text])", name: "check_status"
  end

  create_table "wallets", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "currency", default: "USD", null: false
    t.decimal "balance", precision: 20, scale: 8, default: "0.0", null: false
    t.decimal "locked_balance", precision: 20, scale: 8, default: "0.0", null: false
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_wallets_on_status"
    t.index ["user_id", "currency"], name: "index_wallets_user_currency_unique", unique: true
    t.index ["user_id"], name: "index_wallets_on_user_id"
    t.check_constraint "balance >= 0::numeric", name: "check_wallet_balance_non_negative"
    t.check_constraint "locked_balance >= 0::numeric", name: "check_wallet_locked_balance_non_negative"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'suspended'::character varying::text, 'closed'::character varying::text])", name: "check_wallet_status"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "artist_categories", "categories", on_delete: :cascade
  add_foreign_key "artist_categories", "users", on_delete: :cascade
  add_foreign_key "categories", "categories_groups", on_delete: :cascade
  add_foreign_key "crypto_wallets", "users", on_delete: :cascade
  add_foreign_key "devices", "users"
  add_foreign_key "notifications", "users", on_delete: :cascade
  add_foreign_key "otps", "users"
  add_foreign_key "payment_methods", "users", on_delete: :cascade
  add_foreign_key "payment_transactions", "users", on_delete: :restrict
  add_foreign_key "payment_transactions", "wallets", on_delete: :restrict
  add_foreign_key "properties", "users", column: "approved_by_id", on_delete: :nullify
  add_foreign_key "properties", "users", column: "owner_id"
  add_foreign_key "properties", "users", column: "rejected_by_id", on_delete: :nullify
  add_foreign_key "user_blocks", "users", column: "blocked_id", on_delete: :cascade
  add_foreign_key "user_blocks", "users", column: "blocker_id", on_delete: :cascade
  add_foreign_key "user_deactivations", "users", on_delete: :cascade
  add_foreign_key "user_reports", "users", column: "reported_id", on_delete: :cascade
  add_foreign_key "user_reports", "users", column: "reporter_id", on_delete: :cascade
  add_foreign_key "user_reports", "users", column: "reviewed_by_id", on_delete: :nullify
  add_foreign_key "wallets", "users", on_delete: :cascade
end
