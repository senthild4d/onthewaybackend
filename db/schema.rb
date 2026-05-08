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

ActiveRecord::Schema[8.0].define(version: 2026_05_08_000034) do
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

  create_table "favorites", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "property_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["property_id"], name: "index_favorites_on_property_id"
    t.index ["user_id", "property_id"], name: "index_favorites_on_user_id_and_property_id", unique: true
  end

  create_table "legal_documents", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["kind"], name: "index_legal_documents_on_kind", unique: true
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
    t.string "purpose", default: "sale", null: false
    t.string "listing_status", default: "active", null: false
    t.datetime "sold_at"
    t.uuid "sold_by_id"
    t.datetime "archived_at"
    t.uuid "archived_by_id"
    t.decimal "area_sqm", precision: 12, scale: 2
    t.integer "year_built"
    t.integer "floor"
    t.integer "total_floors"
    t.boolean "furnished"
    t.integer "parking_spaces"
    t.jsonb "features", default: {}, null: false
    t.index ["approval_status"], name: "index_properties_on_approval_status"
    t.index ["archived_at"], name: "index_properties_on_archived_at"
    t.index ["archived_by_id"], name: "index_properties_on_archived_by_id"
    t.index ["area_sqm"], name: "index_properties_on_area_sqm"
    t.index ["bathrooms"], name: "index_properties_on_bathrooms"
    t.index ["bedrooms"], name: "index_properties_on_bedrooms"
    t.index ["latitude", "longitude"], name: "index_properties_on_latitude_and_longitude"
    t.index ["listing_status"], name: "index_properties_on_listing_status"
    t.index ["owner_id"], name: "index_properties_on_owner_id"
    t.index ["price"], name: "index_properties_on_price"
    t.index ["property_type"], name: "index_properties_on_property_type"
    t.index ["purpose"], name: "index_properties_on_purpose"
    t.index ["sold_at"], name: "index_properties_on_sold_at"
    t.index ["sold_by_id"], name: "index_properties_on_sold_by_id"
    t.check_constraint "approval_status::text = ANY (ARRAY['draft'::character varying::text, 'pending_review'::character varying::text, 'approved'::character varying::text, 'rejected'::character varying::text, 'archived'::character varying::text])", name: "check_properties_approval_status"
    t.check_constraint "area_sqm IS NULL OR area_sqm >= 0::numeric", name: "check_properties_area_sqm_non_negative"
    t.check_constraint "floor IS NULL OR floor >= '-5'::integer", name: "check_properties_floor_min"
    t.check_constraint "latitude IS NULL OR latitude >= '-90'::integer::numeric AND latitude <= 90::numeric", name: "check_properties_latitude"
    t.check_constraint "listing_status::text = ANY (ARRAY['active'::character varying, 'sold'::character varying, 'archived'::character varying]::text[])", name: "check_properties_listing_status"
    t.check_constraint "longitude IS NULL OR longitude >= '-180'::integer::numeric AND longitude <= 180::numeric", name: "check_properties_longitude"
    t.check_constraint "parking_spaces IS NULL OR parking_spaces >= 0", name: "check_properties_parking_non_negative"
    t.check_constraint "price IS NULL OR price >= 0::numeric", name: "check_properties_price_non_negative"
    t.check_constraint "purpose::text = ANY (ARRAY['sale'::character varying, 'rent'::character varying]::text[])", name: "check_properties_purpose"
    t.check_constraint "year_built IS NULL OR year_built >= 1600 AND year_built <= (EXTRACT(year FROM now())::integer + 1)", name: "check_properties_year_built"
  end

  create_table "property_viewings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "property_id", null: false
    t.uuid "user_id", null: false
    t.string "status", default: "requested", null: false
    t.datetime "requested_for"
    t.text "message"
    t.string "contact_phone"
    t.string "contact_email"
    t.uuid "handled_by_id"
    t.datetime "handled_at"
    t.text "admin_notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["handled_by_id"], name: "index_property_viewings_on_handled_by_id"
    t.index ["property_id"], name: "index_property_viewings_on_property_id"
    t.index ["requested_for"], name: "index_property_viewings_on_requested_for"
    t.index ["status"], name: "index_property_viewings_on_status"
    t.index ["user_id"], name: "index_property_viewings_on_user_id"
    t.check_constraint "status::text = ANY (ARRAY['requested'::character varying, 'confirmed'::character varying, 'cancelled'::character varying, 'completed'::character varying]::text[])", name: "check_property_viewings_status"
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
    t.boolean "is_admin", default: false, null: false
    t.index ["created_at"], name: "index_users_on_created_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["is_admin"], name: "index_users_on_is_admin"
    t.index ["phone"], name: "index_users_on_phone", unique: true, where: "(phone IS NOT NULL)"
    t.index ["role"], name: "index_users_on_role"
    t.index ["status"], name: "index_users_on_status"
    t.index ["username"], name: "index_users_on_username", unique: true, where: "(username IS NOT NULL)"
    t.check_constraint "email::text ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}$'::text", name: "check_email_format"
    t.check_constraint "phone IS NOT NULL OR email IS NOT NULL", name: "check_user_phone_or_email"
    t.check_constraint "role::text = ANY (ARRAY['user'::character varying, 'owner'::character varying]::text[])", name: "check_role"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'disabled'::character varying::text])", name: "check_status"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "devices", "users"
  add_foreign_key "favorites", "properties", on_delete: :cascade
  add_foreign_key "favorites", "users", on_delete: :cascade
  add_foreign_key "otps", "users"
  add_foreign_key "properties", "users", column: "approved_by_id", on_delete: :nullify
  add_foreign_key "properties", "users", column: "archived_by_id", on_delete: :nullify
  add_foreign_key "properties", "users", column: "owner_id"
  add_foreign_key "properties", "users", column: "rejected_by_id", on_delete: :nullify
  add_foreign_key "properties", "users", column: "sold_by_id", on_delete: :nullify
  add_foreign_key "property_viewings", "properties", on_delete: :cascade
  add_foreign_key "property_viewings", "users", column: "handled_by_id", on_delete: :nullify
  add_foreign_key "property_viewings", "users", on_delete: :cascade
  add_foreign_key "user_blocks", "users", column: "blocked_id", on_delete: :cascade
  add_foreign_key "user_blocks", "users", column: "blocker_id", on_delete: :cascade
  add_foreign_key "user_deactivations", "users", on_delete: :cascade
  add_foreign_key "user_reports", "users", column: "reported_id", on_delete: :cascade
  add_foreign_key "user_reports", "users", column: "reporter_id", on_delete: :cascade
  add_foreign_key "user_reports", "users", column: "reviewed_by_id", on_delete: :nullify
end
