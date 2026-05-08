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

ActiveRecord::Schema[8.0].define(version: 2026_03_31_090000) do
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

  create_table "bill_splits", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "food_bar_order_id", null: false
    t.uuid "user_id"
    t.string "split_name"
    t.string "split_email"
    t.string "split_phone"
    t.decimal "split_amount", precision: 10, scale: 2, null: false
    t.string "payment_status", default: "pending", null: false
    t.uuid "payment_transaction_id"
    t.datetime "paid_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["food_bar_order_id"], name: "index_bill_splits_on_food_bar_order_id"
    t.index ["payment_status"], name: "index_bill_splits_on_payment_status"
    t.index ["user_id"], name: "index_bill_splits_on_user_id"
    t.check_constraint "payment_status::text = ANY (ARRAY['pending'::character varying::text, 'paid'::character varying::text, 'failed'::character varying::text, 'refunded'::character varying::text])", name: "check_bill_split_payment_status"
    t.check_constraint "split_amount >= 0::numeric", name: "check_bill_split_amount"
  end

  create_table "booking_ticket_lines", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "booking_id", null: false
    t.uuid "event_ticket_type_id", null: false
    t.integer "quantity", null: false
    t.decimal "unit_price", precision: 10, scale: 2, null: false
    t.decimal "line_total", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["booking_id"], name: "index_booking_ticket_lines_on_booking_id"
    t.index ["event_ticket_type_id"], name: "index_booking_ticket_lines_on_event_ticket_type_id"
    t.check_constraint "quantity > 0", name: "check_booking_ticket_lines_qty"
  end

  create_table "bookings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "event_id", null: false
    t.string "status", default: "created", null: false
    t.datetime "checked_in_at"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "price", precision: 10, scale: 2, default: "0.0", null: false
    t.string "currency", default: "USD", null: false
    t.string "payment_status", default: "pending", null: false
    t.uuid "payment_transaction_id"
    t.string "payment_method"
    t.datetime "paid_at"
    t.datetime "canceled_at"
    t.decimal "refund_amount", precision: 10, scale: 2
    t.decimal "cancellation_fee", precision: 10, scale: 2
    t.string "table_number"
    t.uuid "assigned_by_id"
    t.datetime "table_assigned_at"
    t.boolean "cancellation_requested", default: false, null: false
    t.datetime "cancellation_requested_at"
    t.text "cancellation_reason"
    t.boolean "cancellation_approved"
    t.uuid "cancellation_approved_by_id"
    t.datetime "cancellation_approved_at"
    t.text "cancellation_rejected_reason"
    t.integer "adults_count", default: 1, null: false
    t.integer "children_count", default: 0, null: false
    t.integer "infants_count", default: 0, null: false
    t.integer "pets_count", default: 0, null: false
    t.uuid "promo_code_id"
    t.string "promo_code"
    t.decimal "original_price", precision: 10, scale: 2
    t.decimal "discount_amount", precision: 10, scale: 2
    t.decimal "paid_amount", precision: 10, scale: 2, default: "0.0", null: false
    t.string "payment_type"
    t.datetime "expiry_at"
    t.index ["canceled_at"], name: "index_bookings_on_canceled_at"
    t.index ["cancellation_approved"], name: "index_bookings_on_cancellation_approved"
    t.index ["cancellation_requested"], name: "index_bookings_on_cancellation_requested"
    t.index ["checked_in_at"], name: "index_bookings_on_checked_in_at"
    t.index ["event_id"], name: "index_bookings_on_event_id"
    t.index ["payment_status"], name: "index_bookings_on_payment_status"
    t.index ["payment_transaction_id"], name: "index_bookings_on_payment_transaction_id"
    t.index ["payment_type"], name: "index_bookings_on_payment_type"
    t.index ["promo_code_id"], name: "index_bookings_on_promo_code_id"
    t.index ["status"], name: "index_bookings_on_status"
    t.index ["table_number"], name: "index_bookings_on_table_number"
    t.index ["user_id", "event_id"], name: "index_bookings_on_user_id_and_event_id"
    t.index ["user_id"], name: "index_bookings_on_user_id"
    t.check_constraint "paid_amount >= 0::numeric", name: "check_booking_paid_amount"
    t.check_constraint "payment_status::text = ANY (ARRAY['pending'::character varying::text, 'partial'::character varying::text, 'paid'::character varying::text, 'failed'::character varying::text, 'refunded'::character varying::text])", name: "check_booking_payment_status"
    t.check_constraint "status::text = ANY (ARRAY['created'::character varying::text, 'confirmed'::character varying::text, 'canceled'::character varying::text, 'checked_in'::character varying::text])", name: "check_booking_status"
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

  create_table "chat_messages", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "chat_id", null: false
    t.uuid "sender_id", null: false
    t.text "content", null: false
    t.string "message_type", default: "text", null: false
    t.uuid "reply_to_id"
    t.uuid "forwarded_from_id"
    t.string "forwarded_from_type"
    t.boolean "is_edited", default: false, null: false
    t.datetime "edited_at"
    t.datetime "deleted_at"
    t.boolean "is_read", default: false, null: false
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_id"], name: "index_chat_messages_on_chat_id"
    t.index ["created_at"], name: "index_chat_messages_on_created_at"
    t.index ["deleted_at"], name: "index_chat_messages_on_deleted_at"
    t.index ["forwarded_from_id"], name: "index_chat_messages_on_forwarded_from_id"
    t.index ["is_read"], name: "index_chat_messages_on_is_read"
    t.index ["reply_to_id"], name: "index_chat_messages_on_reply_to_id"
    t.index ["sender_id"], name: "index_chat_messages_on_sender_id"
    t.check_constraint "message_type::text = ANY (ARRAY['text'::character varying::text, 'image'::character varying::text, 'video'::character varying::text, 'audio'::character varying::text, 'location'::character varying::text])", name: "check_chat_message_type"
  end

  create_table "chats", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user1_id", null: false
    t.uuid "user2_id", null: false
    t.datetime "last_message_at"
    t.boolean "user1_blocked", default: false, null: false
    t.boolean "user2_blocked", default: false, null: false
    t.boolean "user1_muted", default: false, null: false
    t.boolean "user2_muted", default: false, null: false
    t.boolean "user1_pinned", default: false, null: false
    t.boolean "user2_pinned", default: false, null: false
    t.boolean "user1_archived", default: false, null: false
    t.boolean "user2_archived", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["last_message_at"], name: "index_chats_on_last_message_at"
    t.index ["user1_id", "user2_id"], name: "index_chats_users_unique", unique: true
    t.index ["user1_id"], name: "index_chats_on_user1_id"
    t.index ["user2_id"], name: "index_chats_on_user2_id"
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

  create_table "event_artists", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "event_id", null: false
    t.uuid "artist_id"
    t.datetime "scheduled_start_at", null: false
    t.datetime "scheduled_end_at", null: false
    t.string "timezone", default: "UTC", null: false
    t.integer "display_order", default: 0, null: false
    t.text "description"
    t.string "status", default: "confirmed", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "artist_name"
    t.index ["artist_id"], name: "index_event_artists_on_artist_id"
    t.index ["display_order"], name: "index_event_artists_on_display_order"
    t.index ["event_id", "artist_id"], name: "index_event_artists_event_artist_unique", unique: true, where: "(artist_id IS NOT NULL)"
    t.index ["event_id"], name: "index_event_artists_on_event_id"
    t.index ["scheduled_start_at"], name: "index_event_artists_on_scheduled_start_at"
    t.index ["status"], name: "index_event_artists_on_status"
    t.check_constraint "scheduled_end_at > scheduled_start_at", name: "check_event_artist_schedule"
    t.check_constraint "status::text = ANY (ARRAY['confirmed'::character varying::text, 'pending'::character varying::text, 'cancelled'::character varying::text])", name: "check_event_artist_status"
  end

  create_table "event_boosts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "event_id", null: false
    t.uuid "created_by_id", null: false
    t.string "performance_goal", default: "page_views", null: false
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.string "timezone", default: "UTC"
    t.integer "target_age_min", default: 18
    t.integer "target_age_max", default: 65
    t.string "target_gender", default: "all"
    t.string "geo_fence_address"
    t.string "geo_fence_city"
    t.string "geo_fence_region"
    t.string "geo_fence_country"
    t.decimal "geo_fence_latitude", precision: 10, scale: 6
    t.decimal "geo_fence_longitude", precision: 10, scale: 6
    t.decimal "geo_fence_radius_km", precision: 8, scale: 2, default: "10.0"
    t.decimal "daily_budget", precision: 10, scale: 2
    t.decimal "total_budget", precision: 10, scale: 2
    t.string "currency", default: "USD"
    t.decimal "amount_spent", precision: 10, scale: 2, default: "0.0"
    t.integer "impressions_count", default: 0
    t.integer "page_views_count", default: 0
    t.integer "link_clicks_count", default: 0
    t.integer "unique_reach_count", default: 0
    t.string "status", default: "draft", null: false
    t.datetime "approved_at"
    t.datetime "paused_at"
    t.datetime "completed_at"
    t.datetime "rejected_at"
    t.datetime "cancelled_at"
    t.string "rejection_reason"
    t.text "notes"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_event_boosts_on_created_by_id"
    t.index ["event_id"], name: "index_event_boosts_on_event_id"
    t.index ["geo_fence_latitude", "geo_fence_longitude"], name: "index_event_boosts_on_geo_fence_coords"
    t.index ["performance_goal"], name: "index_event_boosts_on_performance_goal"
    t.index ["starts_at", "ends_at"], name: "index_event_boosts_on_starts_at_and_ends_at"
    t.index ["status"], name: "index_event_boosts_on_status"
    t.index ["target_age_min", "target_age_max"], name: "index_event_boosts_on_target_age_min_and_target_age_max"
    t.index ["target_gender"], name: "index_event_boosts_on_target_gender"
    t.check_constraint "geo_fence_radius_km IS NULL OR geo_fence_radius_km > 0::numeric AND geo_fence_radius_km <= 500::numeric", name: "event_boosts_geo_fence_radius_check"
    t.check_constraint "performance_goal::text = ANY (ARRAY['page_views'::character varying::text, 'link_clicks'::character varying::text, 'daily_reach'::character varying::text])", name: "event_boosts_performance_goal_check"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying::text, 'pending_review'::character varying::text, 'active'::character varying::text, 'paused'::character varying::text, 'completed'::character varying::text, 'rejected'::character varying::text, 'cancelled'::character varying::text])", name: "event_boosts_status_check"
    t.check_constraint "target_age_min >= 0 AND target_age_min <= 120 AND target_age_max >= 0 AND target_age_max <= 120 AND target_age_min <= target_age_max", name: "event_boosts_age_range_check"
    t.check_constraint "target_gender::text = ANY (ARRAY['all'::character varying::text, 'male'::character varying::text, 'female'::character varying::text, 'other'::character varying::text])", name: "event_boosts_target_gender_check"
  end

  create_table "event_categories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "event_id", null: false
    t.uuid "category_id", null: false
    t.string "source", default: "manual", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_event_categories_on_category_id"
    t.index ["event_id", "category_id"], name: "index_event_categories_on_event_id_and_category_id", unique: true
    t.index ["event_id"], name: "index_event_categories_on_event_id"
  end

  create_table "event_custom_categories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "event_id", null: false
    t.string "name", limit: 255, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "name"], name: "index_event_custom_categories_on_event_and_name", unique: true
    t.index ["event_id"], name: "index_event_custom_categories_on_event_id"
    t.index ["name"], name: "index_event_custom_categories_on_name"
  end

  create_table "event_interests", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "event_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "rsvp_status"
    t.integer "guest_count", default: 0, null: false
    t.text "notes"
    t.datetime "responded_at"
    t.index ["event_id"], name: "index_event_interests_on_event_id"
    t.index ["rsvp_status"], name: "index_event_interests_on_rsvp_status"
    t.index ["user_id", "event_id"], name: "index_event_interests_user_event_unique", unique: true
    t.index ["user_id"], name: "index_event_interests_on_user_id"
    t.check_constraint "rsvp_status IS NULL OR (rsvp_status::text = ANY (ARRAY['yes'::character varying::text, 'no'::character varying::text, 'maybe'::character varying::text]))", name: "check_rsvp_status"
  end

  create_table "event_menus", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "event_id", null: false
    t.string "name", null: false
    t.string "menu_type", null: false
    t.text "description"
    t.boolean "is_active", default: true, null: false
    t.datetime "available_from"
    t.datetime "available_until"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_event_menus_on_event_id"
    t.index ["is_active"], name: "index_event_menus_on_is_active"
    t.index ["menu_type"], name: "index_event_menus_on_menu_type"
    t.check_constraint "menu_type::text = ANY (ARRAY['food'::character varying::text, 'bar'::character varying::text, 'both'::character varying::text])", name: "check_event_menu_type"
  end

  create_table "event_posts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "event_id", null: false
    t.uuid "user_id", null: false
    t.text "content"
    t.string "status", default: "active", null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_event_posts_on_deleted_at"
    t.index ["event_id", "created_at"], name: "index_event_posts_on_event_id_and_created_at"
    t.index ["event_id"], name: "index_event_posts_on_event_id"
    t.index ["status"], name: "index_event_posts_on_status"
    t.index ["user_id", "created_at"], name: "index_event_posts_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_event_posts_on_user_id"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'hidden'::character varying::text, 'deleted'::character varying::text])", name: "check_event_post_status"
  end

  create_table "event_reports", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "event_id", null: false
    t.uuid "reporter_id", null: false
    t.string "reason", null: false
    t.text "description"
    t.string "status", default: "pending", null: false
    t.uuid "reviewed_by_id"
    t.text "admin_notes"
    t.datetime "reviewed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "reporter_id"], name: "index_event_reports_event_reporter_unique", unique: true
    t.index ["event_id"], name: "index_event_reports_on_event_id"
    t.index ["reporter_id"], name: "index_event_reports_on_reporter_id"
    t.index ["status"], name: "index_event_reports_on_status"
    t.check_constraint "reason::text = ANY (ARRAY['spam'::character varying::text, 'inappropriate'::character varying::text, 'misleading'::character varying::text, 'duplicate'::character varying::text, 'violence'::character varying::text, 'harassment'::character varying::text, 'other'::character varying::text])", name: "check_event_report_reason"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'reviewed'::character varying::text, 'resolved'::character varying::text, 'dismissed'::character varying::text])", name: "check_event_report_status"
  end

  create_table "event_tags", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "slug", null: false
    t.string "name", null: false
    t.string "country"
    t.boolean "is_default", default: false, null: false
    t.integer "display_order", default: 0, null: false
    t.string "category_slug"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["country"], name: "index_event_tags_on_country"
    t.index ["is_default"], name: "index_event_tags_on_is_default"
    t.index ["slug", "country"], name: "index_event_tags_on_slug_and_country", unique: true, where: "(country IS NOT NULL)"
    t.index ["slug"], name: "index_event_tags_on_slug_when_global", unique: true, where: "(country IS NULL)"
  end

  create_table "event_ticket_types", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "event_id", null: false
    t.string "name", null: false
    t.decimal "price", precision: 10, scale: 2, default: "0.0", null: false
    t.string "currency", limit: 8
    t.integer "quantity_total", default: 0, null: false
    t.integer "quantity_sold", default: 0, null: false
    t.integer "display_order", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "display_order"], name: "index_event_ticket_types_on_event_and_order"
    t.index ["event_id"], name: "index_event_ticket_types_on_event_id"
    t.check_constraint "quantity_sold <= quantity_total", name: "check_event_ticket_types_sold_lte_total"
    t.check_constraint "quantity_sold >= 0", name: "check_event_ticket_types_qty_sold"
    t.check_constraint "quantity_total >= 0", name: "check_event_ticket_types_qty_total"
  end

  create_table "events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "venue_id"
    t.string "title", null: false
    t.text "description"
    t.string "category", limit: 50
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.string "timezone", default: "UTC", null: false
    t.string "status", default: "draft", null: false
    t.datetime "published_at"
    t.datetime "live_at"
    t.datetime "blocked_at"
    t.uuid "blocked_by_id"
    t.string "block_scope", limit: 20
    t.text "block_reason"
    t.integer "age_restriction"
    t.string "visibility", default: "public", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "address1"
    t.string "address2"
    t.string "city"
    t.string "region"
    t.string "postal_code"
    t.string "country"
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "longitude", precision: 10, scale: 7
    t.decimal "price", precision: 10, scale: 2, default: "0.0", null: false
    t.string "currency", default: "USD", null: false
    t.boolean "is_free", default: true, null: false
    t.decimal "pre_booking_price", precision: 10, scale: 2
    t.datetime "pre_booking_deadline"
    t.boolean "id_required", default: false, null: false
    t.text "id_requirement_description"
    t.text "dress_code"
    t.text "restrictions"
    t.text "access_instructions"
    t.boolean "cancellation_policy_enabled", default: false, null: false
    t.integer "cancellation_deadline_hours", comment: "Hours before event when full refund is available (e.g., 24 = cancel 24 hours before)"
    t.decimal "cancellation_fee_percentage", precision: 5, scale: 2, default: "0.0", comment: "Percentage of booking price charged as cancellation fee after deadline (0-100)"
    t.json "photo_urls", default: []
    t.string "poster_url"
    t.string "smoking", limit: 20
    t.decimal "adult_price", precision: 10, scale: 2
    t.decimal "child_price", precision: 10, scale: 2
    t.decimal "infant_price", precision: 10, scale: 2
    t.decimal "pet_price", precision: 10, scale: 2
    t.boolean "booking_opens_after_event_start", default: false, null: false
    t.string "collaborator_type"
    t.uuid "collaborator_id"
    t.uuid "creator_id"
    t.string "attendance_mode", limit: 20, default: "rsvp"
    t.string "pr_commission_type", limit: 20, comment: "exclusive=2%, non_exclusive=5% (business-side fee)"
    t.string "invite_token"
    t.string "invite_sharing", default: "creator_and_guests", null: false
    t.index ["blocked_by_id"], name: "index_events_on_blocked_by_id"
    t.index ["cancellation_policy_enabled"], name: "index_events_on_cancellation_policy_enabled"
    t.index ["category"], name: "index_events_on_category"
    t.index ["collaborator_type", "collaborator_id"], name: "index_events_on_collaborator_type_and_collaborator_id"
    t.index ["creator_id"], name: "index_events_on_creator_id"
    t.index ["id_required"], name: "index_events_on_id_required"
    t.index ["invite_token"], name: "index_events_on_invite_token", unique: true, where: "(invite_token IS NOT NULL)"
    t.index ["is_free"], name: "index_events_on_is_free"
    t.index ["poster_url"], name: "index_events_on_poster_url", where: "(poster_url IS NOT NULL)"
    t.index ["pre_booking_deadline"], name: "index_events_on_pre_booking_deadline"
    t.index ["price"], name: "index_events_on_price"
    t.index ["smoking"], name: "index_events_on_smoking"
    t.index ["starts_at"], name: "index_events_on_starts_at"
    t.index ["status", "starts_at"], name: "index_events_status_starts_at"
    t.index ["status"], name: "index_events_on_status"
    t.index ["venue_id"], name: "index_events_on_venue_id"
    t.index ["visibility"], name: "index_events_on_visibility"
    t.check_constraint "age_restriction IS NULL OR age_restriction >= 0 AND age_restriction <= 99", name: "check_event_age_restriction"
    t.check_constraint "attendance_mode IS NULL OR (attendance_mode::text = ANY (ARRAY['rsvp'::character varying, 'tickets'::character varying]::text[]))", name: "check_event_attendance_mode"
    t.check_constraint "block_scope IS NULL OR (block_scope::text = ANY (ARRAY['sales'::character varying::text, 'visibility'::character varying::text, 'checkin'::character varying::text, 'all'::character varying::text]))", name: "check_event_block_scope"
    t.check_constraint "cancellation_deadline_hours IS NULL OR cancellation_deadline_hours >= 0", name: "check_cancellation_deadline_hours"
    t.check_constraint "cancellation_fee_percentage >= 0::numeric AND cancellation_fee_percentage <= 100::numeric", name: "check_cancellation_fee_percentage"
    t.check_constraint "ends_at > starts_at", name: "check_event_dates"
    t.check_constraint "invite_sharing::text = ANY (ARRAY['creator_only'::character varying, 'creator_and_guests'::character varying]::text[])", name: "check_event_invite_sharing"
    t.check_constraint "latitude IS NULL OR latitude >= '-90'::integer::numeric AND latitude <= 90::numeric", name: "check_event_latitude"
    t.check_constraint "longitude IS NULL OR longitude >= '-180'::integer::numeric AND longitude <= 180::numeric", name: "check_event_longitude"
    t.check_constraint "pr_commission_type IS NULL OR (pr_commission_type::text = ANY (ARRAY['exclusive'::character varying, 'non_exclusive'::character varying]::text[]))", name: "check_event_pr_commission_type"
    t.check_constraint "smoking IS NULL OR (smoking::text = ANY (ARRAY['yes'::character varying::text, 'no'::character varying::text, '2 zones'::character varying::text, 'private zone'::character varying::text]))", name: "check_event_smoking"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying::text, 'published'::character varying::text, 'canceled'::character varying::text, 'completed'::character varying::text])", name: "check_event_status"
    t.check_constraint "visibility::text = ANY (ARRAY['public'::character varying::text, 'private'::character varying::text, 'unlisted'::character varying::text])", name: "check_event_visibility"
  end

  create_table "floor_plan_elements", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "floor_plan_id", null: false
    t.string "element_type", null: false
    t.string "name"
    t.jsonb "geometry", null: false
    t.string "color"
    t.decimal "rotation", precision: 10, scale: 2, default: "0.0"
    t.integer "display_order", default: 0, null: false
    t.jsonb "properties", default: {}
    t.boolean "is_visible", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["element_type"], name: "index_floor_plan_elements_on_element_type"
    t.index ["floor_plan_id", "display_order"], name: "index_floor_plan_elements_on_floor_plan_id_and_display_order"
    t.index ["floor_plan_id"], name: "index_floor_plan_elements_on_floor_plan_id"
    t.check_constraint "element_type::text = ANY (ARRAY['wall'::character varying::text, 'door'::character varying::text, 'window'::character varying::text, 'pillar'::character varying::text, 'decor'::character varying::text, 'bar'::character varying::text, 'stage'::character varying::text, 'entrance'::character varying::text, 'exit'::character varying::text, 'restroom'::character varying::text, 'kitchen'::character varying::text, 'other'::character varying::text])", name: "check_element_type"
  end

  create_table "floor_plan_zones", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "floor_plan_id", null: false
    t.string "name", null: false
    t.string "zone_type", null: false
    t.jsonb "geometry", null: false
    t.string "color", default: "#cccccc"
    t.integer "display_order", default: 0, null: false
    t.integer "capacity"
    t.boolean "is_bookable", default: true, null: false
    t.boolean "is_active", default: true, null: false
    t.decimal "min_spend", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["floor_plan_id", "display_order"], name: "index_floor_plan_zones_on_floor_plan_id_and_display_order"
    t.index ["floor_plan_id"], name: "index_floor_plan_zones_on_floor_plan_id"
    t.index ["zone_type"], name: "index_floor_plan_zones_on_zone_type"
    t.check_constraint "capacity IS NULL OR capacity > 0", name: "check_zone_capacity"
    t.check_constraint "zone_type::text = ANY (ARRAY['dining'::character varying::text, 'bar'::character varying::text, 'vip'::character varying::text, 'outdoor'::character varying::text, 'stage'::character varying::text, 'dance_floor'::character varying::text, 'gaming'::character varying::text, 'other'::character varying::text])", name: "check_zone_type"
  end

  create_table "floor_plans", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "venue_id", null: false
    t.string "name", null: false
    t.text "description"
    t.string "venue_type", null: false
    t.integer "width", default: 1000, null: false
    t.integer "height", default: 1000, null: false
    t.decimal "scale_factor", precision: 10, scale: 2, default: "1.0"
    t.jsonb "settings", default: {}, null: false
    t.text "thumbnail_url"
    t.string "status", default: "draft", null: false
    t.boolean "is_default", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_floor_plans_on_status"
    t.index ["venue_id", "is_default"], name: "index_floor_plans_on_venue_id_and_is_default"
    t.index ["venue_id"], name: "index_floor_plans_on_venue_id"
    t.index ["venue_type"], name: "index_floor_plans_on_venue_type"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying::text, 'active'::character varying::text, 'archived'::character varying::text])", name: "check_floor_plan_status"
    t.check_constraint "venue_type::text = ANY (ARRAY['restaurant'::character varying::text, 'pub'::character varying::text, 'bar'::character varying::text, 'casino'::character varying::text, 'gaming'::character varying::text, 'sports'::character varying::text, 'club'::character varying::text, 'lounge'::character varying::text, 'cafe'::character varying::text, 'other'::character varying::text])", name: "check_floor_plan_venue_type"
    t.check_constraint "width > 0 AND height > 0", name: "check_floor_plan_dimensions"
  end

  create_table "follow_requests", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "requester_id", null: false
    t.uuid "requested_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "responded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["requested_id"], name: "index_follow_requests_on_requested_id"
    t.index ["requester_id", "requested_id"], name: "index_follow_requests_pending_unique", unique: true, where: "((status)::text = 'pending'::text)"
    t.index ["requester_id"], name: "index_follow_requests_on_requester_id"
    t.index ["status"], name: "index_follow_requests_on_status"
  end

  create_table "follows", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "follower_id", null: false
    t.uuid "following_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["follower_id", "following_id"], name: "index_follows_follower_following_unique", unique: true
    t.index ["follower_id"], name: "index_follows_on_follower_id"
    t.index ["following_id"], name: "index_follows_on_following_id"
  end

  create_table "food_bar_order_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "food_bar_order_id", null: false
    t.uuid "menu_item_id", null: false
    t.integer "quantity", default: 1, null: false
    t.decimal "unit_price", precision: 10, scale: 2, null: false
    t.decimal "total_price", precision: 10, scale: 2, null: false
    t.text "customizations"
    t.text "special_instructions"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["food_bar_order_id"], name: "index_food_bar_order_items_on_food_bar_order_id"
    t.index ["menu_item_id"], name: "index_food_bar_order_items_on_menu_item_id"
    t.check_constraint "quantity > 0", name: "check_food_bar_order_item_quantity"
    t.check_constraint "unit_price >= 0::numeric", name: "check_food_bar_order_item_unit_price"
  end

  create_table "food_bar_orders", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "event_id", null: false
    t.uuid "user_id", null: false
    t.uuid "booking_id"
    t.string "order_number", null: false
    t.string "status", default: "pending", null: false
    t.string "order_type", null: false
    t.decimal "subtotal", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "tax", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "tip_amount", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "tip_percentage", precision: 5, scale: 2
    t.decimal "total_amount", precision: 10, scale: 2, default: "0.0", null: false
    t.string "currency", default: "USD", null: false
    t.text "special_instructions"
    t.text "dietary_restrictions"
    t.text "allergies"
    t.boolean "is_split_bill", default: false, null: false
    t.integer "split_count", default: 1
    t.string "payment_status", default: "pending", null: false
    t.uuid "payment_transaction_id"
    t.datetime "ordered_at"
    t.datetime "confirmed_at"
    t.datetime "preparing_at"
    t.datetime "ready_at"
    t.datetime "delivered_at"
    t.datetime "completed_at"
    t.datetime "canceled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "table_number"
    t.datetime "time_window_start"
    t.datetime "time_window_end"
    t.index ["booking_id"], name: "index_food_bar_orders_on_booking_id"
    t.index ["event_id"], name: "index_food_bar_orders_on_event_id"
    t.index ["order_number"], name: "index_food_bar_orders_on_order_number", unique: true
    t.index ["order_type"], name: "index_food_bar_orders_on_order_type"
    t.index ["ordered_at"], name: "index_food_bar_orders_on_ordered_at"
    t.index ["payment_status"], name: "index_food_bar_orders_on_payment_status"
    t.index ["status"], name: "index_food_bar_orders_on_status"
    t.index ["table_number"], name: "index_food_bar_orders_on_table_number"
    t.index ["time_window_end"], name: "index_food_bar_orders_on_time_window_end"
    t.index ["time_window_start"], name: "index_food_bar_orders_on_time_window_start"
    t.index ["user_id"], name: "index_food_bar_orders_on_user_id"
    t.check_constraint "order_type::text = ANY (ARRAY['food'::character varying::text, 'bar'::character varying::text, 'both'::character varying::text])", name: "check_food_bar_order_type"
    t.check_constraint "payment_status::text = ANY (ARRAY['pending'::character varying::text, 'paid'::character varying::text, 'failed'::character varying::text, 'refunded'::character varying::text, 'split_pending'::character varying::text])", name: "check_food_bar_order_payment_status"
    t.check_constraint "split_count >= 1", name: "check_food_bar_order_split_count"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'confirmed'::character varying::text, 'preparing'::character varying::text, 'ready'::character varying::text, 'delivered'::character varying::text, 'completed'::character varying::text, 'canceled'::character varying::text])", name: "check_food_bar_order_status"
    t.check_constraint "time_window_start IS NULL OR time_window_end IS NULL OR time_window_end >= time_window_start", name: "check_food_bar_order_time_window"
  end

  create_table "group_chat_memberships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "group_chat_id", null: false
    t.uuid "user_id", null: false
    t.string "role", default: "member", null: false
    t.datetime "joined_at", null: false
    t.datetime "last_read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_muted", default: false, null: false
    t.boolean "is_pinned", default: false, null: false
    t.boolean "is_starred", default: false, null: false
    t.index ["group_chat_id", "user_id"], name: "index_group_chat_memberships_group_chat_user_unique", unique: true
    t.index ["group_chat_id"], name: "index_group_chat_memberships_on_group_chat_id"
    t.index ["is_muted"], name: "index_group_chat_memberships_on_is_muted"
    t.index ["is_pinned"], name: "index_group_chat_memberships_on_is_pinned"
    t.index ["is_starred"], name: "index_group_chat_memberships_on_is_starred"
    t.index ["role"], name: "index_group_chat_memberships_on_role"
    t.index ["user_id"], name: "index_group_chat_memberships_on_user_id"
    t.check_constraint "role::text = ANY (ARRAY['admin'::character varying::text, 'member'::character varying::text])", name: "check_group_chat_membership_role"
  end

  create_table "group_chat_messages", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "group_chat_id", null: false
    t.uuid "user_id", null: false
    t.text "content", null: false
    t.string "message_type", default: "text", null: false
    t.uuid "reply_to_id"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_edited", default: false, null: false
    t.datetime "edited_at"
    t.uuid "forwarded_from_id"
    t.string "forwarded_from_type"
    t.index ["created_at"], name: "index_group_chat_messages_on_created_at"
    t.index ["deleted_at"], name: "index_group_chat_messages_on_deleted_at"
    t.index ["forwarded_from_type", "forwarded_from_id"], name: "idx_on_forwarded_from_type_forwarded_from_id_d7e7233eea"
    t.index ["group_chat_id"], name: "index_group_chat_messages_on_group_chat_id"
    t.index ["is_edited"], name: "index_group_chat_messages_on_is_edited"
    t.index ["reply_to_id"], name: "index_group_chat_messages_on_reply_to_id"
    t.index ["user_id"], name: "index_group_chat_messages_on_user_id"
    t.check_constraint "message_type::text = ANY (ARRAY['text'::character varying::text, 'image'::character varying::text, 'video'::character varying::text, 'audio'::character varying::text, 'location'::character varying::text])", name: "check_group_chat_message_type"
  end

  create_table "group_chats", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.uuid "created_by_id", null: false
    t.string "status", default: "active", null: false
    t.datetime "last_message_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "city"
    t.string "country"
    t.boolean "is_city_based", default: false, null: false
    t.string "invite_code"
    t.string "invite_url"
    t.text "qr_code_data"
    t.index ["city", "country"], name: "index_group_chats_on_city_and_country"
    t.index ["created_by_id"], name: "index_group_chats_on_created_by_id"
    t.index ["invite_code"], name: "index_group_chats_on_invite_code", unique: true
    t.index ["is_city_based", "city", "country"], name: "index_group_chats_city_based"
    t.index ["is_city_based"], name: "index_group_chats_on_is_city_based"
    t.index ["last_message_at"], name: "index_group_chats_on_last_message_at"
    t.index ["status"], name: "index_group_chats_on_status"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'archived'::character varying::text])", name: "check_group_chat_status"
  end

  create_table "likes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "likeable_type", null: false
    t.uuid "likeable_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["likeable_type", "likeable_id"], name: "index_likes_on_likeable"
    t.index ["user_id", "likeable_type", "likeable_id"], name: "index_likes_user_likeable_unique", unique: true
    t.index ["user_id"], name: "index_likes_on_user_id"
    t.check_constraint "likeable_type::text = ANY (ARRAY['Event'::character varying::text, 'Venue'::character varying::text])", name: "check_likeable_type"
  end

  create_table "live_streams", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "venue_id", null: false
    t.uuid "event_id"
    t.string "cloudflare_live_input_uid", null: false
    t.datetime "started_at", null: false
    t.datetime "ended_at"
    t.integer "duration_seconds"
    t.string "status", default: "live", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cloudflare_live_input_uid"], name: "index_live_streams_on_cloudflare_live_input_uid", unique: true
    t.index ["event_id"], name: "index_live_streams_on_event_id"
    t.index ["venue_id", "started_at"], name: "index_live_streams_on_venue_id_and_started_at"
    t.index ["venue_id"], name: "index_live_streams_on_venue_id"
    t.check_constraint "status::text = ANY (ARRAY['live'::character varying, 'ended'::character varying, 'deleted'::character varying]::text[])", name: "check_live_streams_status"
  end

  create_table "menu_categories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "event_menu_id", null: false
    t.string "name", null: false
    t.text "description"
    t.integer "display_order", default: 0, null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "category_type", default: "other", null: false
    t.index ["category_type"], name: "index_menu_categories_on_category_type"
    t.index ["event_menu_id", "display_order"], name: "index_menu_categories_on_event_menu_id_and_display_order"
    t.index ["event_menu_id"], name: "index_menu_categories_on_event_menu_id"
    t.check_constraint "category_type::text = ANY (ARRAY['food'::character varying::text, 'bar'::character varying::text, 'drinks'::character varying::text, 'dessert'::character varying::text, 'appetizer'::character varying::text, 'main'::character varying::text, 'other'::character varying::text])", name: "check_menu_category_type"
  end

  create_table "menu_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "menu_category_id", null: false
    t.string "name", null: false
    t.text "description"
    t.decimal "price", precision: 10, scale: 2, null: false
    t.string "currency", default: "USD", null: false
    t.string "item_type"
    t.string "image_url"
    t.boolean "is_available", default: true, null: false
    t.boolean "is_vegetarian", default: false
    t.boolean "is_vegan", default: false
    t.boolean "is_gluten_free", default: false
    t.boolean "contains_alcohol", default: false
    t.text "allergens", default: [], array: true
    t.text "dietary_info"
    t.integer "preparation_time_minutes"
    t.integer "display_order", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_available"], name: "index_menu_items_on_is_available"
    t.index ["menu_category_id", "display_order"], name: "index_menu_items_on_menu_category_id_and_display_order"
    t.index ["menu_category_id"], name: "index_menu_items_on_menu_category_id"
    t.check_constraint "price >= 0::numeric", name: "check_menu_item_price"
  end

  create_table "moments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "venue_id"
    t.uuid "event_id"
    t.string "audience", default: "public", null: false
    t.string "disappearing_duration", default: "none", null: false
    t.datetime "expires_at"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "projection", default: "flat", null: false
    t.index ["deleted_at"], name: "index_moments_on_deleted_at", where: "(deleted_at IS NULL)"
    t.index ["event_id"], name: "index_moments_on_event_id"
    t.index ["expires_at"], name: "index_moments_on_expires_at", where: "(expires_at IS NOT NULL)"
    t.index ["user_id", "created_at"], name: "index_moments_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_moments_on_user_id"
    t.index ["venue_id"], name: "index_moments_on_venue_id"
    t.check_constraint "audience::text = ANY (ARRAY['public'::character varying, 'followers'::character varying]::text[])", name: "check_moments_audience"
    t.check_constraint "disappearing_duration::text = ANY (ARRAY['24h'::character varying, '72h'::character varying, '1_week'::character varying, '1_month'::character varying, '3_months'::character varying, '6_months'::character varying, '1_year'::character varying, 'none'::character varying]::text[])", name: "check_moments_disappearing_duration"
    t.check_constraint "projection::text = ANY (ARRAY['flat'::character varying, 'equirectangular'::character varying]::text[])", name: "check_moments_projection"
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

  create_table "promo_codes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "event_id"
    t.string "code", null: false
    t.string "label", null: false
    t.text "description"
    t.string "discount_type", null: false
    t.decimal "discount_value", precision: 10, scale: 2, null: false
    t.string "currency"
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.integer "max_uses"
    t.integer "uses_count", default: 0, null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "venue_id"
    t.index ["code"], name: "index_promo_codes_on_code", unique: true
    t.index ["event_id"], name: "index_promo_codes_on_event_id"
    t.index ["is_active"], name: "index_promo_codes_on_is_active"
    t.index ["venue_id"], name: "index_promo_codes_on_venue_id"
    t.check_constraint "discount_type::text = ANY (ARRAY['percentage'::character varying::text, 'fixed'::character varying::text])", name: "check_promo_code_discount_type"
  end

  create_table "ratings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "rateable_type", null: false
    t.uuid "rateable_id", null: false
    t.integer "rating", null: false
    t.text "comment"
    t.string "moderation_status", default: "approved", null: false
    t.datetime "published_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["moderation_status"], name: "index_ratings_on_moderation_status"
    t.index ["published_at"], name: "index_ratings_on_published_at"
    t.index ["rateable_type", "rateable_id"], name: "index_ratings_on_rateable"
    t.index ["user_id", "rateable_type", "rateable_id"], name: "index_ratings_user_rateable_unique", unique: true
    t.index ["user_id"], name: "index_ratings_on_user_id"
    t.check_constraint "moderation_status::text = ANY (ARRAY['pending'::character varying::text, 'approved'::character varying::text, 'rejected'::character varying::text])", name: "check_rating_moderation_status"
    t.check_constraint "rating >= 1 AND rating <= 5", name: "check_rating_range"
  end

  create_table "seats", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "table_id", null: false
    t.integer "seat_number", null: false
    t.decimal "x_position", precision: 10, scale: 2, null: false
    t.decimal "y_position", precision: 10, scale: 2, null: false
    t.string "position_label"
    t.boolean "is_active", default: true, null: false
    t.boolean "is_accessible", default: false
    t.string "seat_type", default: "standard"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["table_id", "seat_number"], name: "index_seats_on_table_id_and_seat_number", unique: true
    t.index ["table_id"], name: "index_seats_on_table_id"
    t.check_constraint "seat_number > 0", name: "check_seat_number"
    t.check_constraint "seat_type::text = ANY (ARRAY['standard'::character varying::text, 'highchair'::character varying::text, 'wheelchair'::character varying::text, 'bar_stool'::character varying::text, 'bench'::character varying::text, 'other'::character varying::text])", name: "check_seat_type"
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

  create_table "stream_views", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "live_stream_id", null: false
    t.integer "watched_seconds", null: false
    t.datetime "viewed_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["live_stream_id"], name: "index_stream_views_on_live_stream_id"
    t.index ["user_id", "live_stream_id"], name: "index_stream_views_on_user_id_and_live_stream_id", unique: true
    t.index ["user_id"], name: "index_stream_views_on_user_id"
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

  create_table "tables", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "floor_plan_zone_id", null: false
    t.string "table_number", null: false
    t.string "table_name"
    t.string "table_type", null: false
    t.string "shape", null: false
    t.decimal "x_position", precision: 10, scale: 2, null: false
    t.decimal "y_position", precision: 10, scale: 2, null: false
    t.decimal "width", precision: 10, scale: 2, null: false
    t.decimal "height", precision: 10, scale: 2, null: false
    t.decimal "rotation", precision: 10, scale: 2, default: "0.0"
    t.integer "min_capacity", default: 1, null: false
    t.integer "max_capacity", null: false
    t.boolean "is_accessible", default: false
    t.boolean "is_active", default: true, null: false
    t.boolean "is_bookable", default: true, null: false
    t.string "color"
    t.jsonb "custom_properties", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["floor_plan_zone_id", "table_number"], name: "index_tables_on_floor_plan_zone_id_and_table_number", unique: true
    t.index ["floor_plan_zone_id"], name: "index_tables_on_floor_plan_zone_id"
    t.index ["is_active"], name: "index_tables_on_is_active"
    t.index ["is_bookable"], name: "index_tables_on_is_bookable"
    t.index ["table_type"], name: "index_tables_on_table_type"
    t.check_constraint "min_capacity > 0 AND max_capacity > 0 AND max_capacity >= min_capacity", name: "check_table_capacity"
    t.check_constraint "shape::text = ANY (ARRAY['rectangle'::character varying::text, 'circle'::character varying::text, 'square'::character varying::text, 'oval'::character varying::text, 'custom'::character varying::text])", name: "check_table_shape"
    t.check_constraint "table_type::text = ANY (ARRAY['standard'::character varying::text, 'booth'::character varying::text, 'bar_stool'::character varying::text, 'highchair'::character varying::text, 'vip'::character varying::text, 'counter'::character varying::text, 'standing'::character varying::text, 'gaming'::character varying::text, 'other'::character varying::text])", name: "check_table_type"
    t.check_constraint "width > 0::numeric AND height > 0::numeric", name: "check_table_dimensions"
  end

  create_table "ticket_entitlements", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "booking_id", null: false
    t.uuid "event_ticket_type_id", null: false
    t.uuid "purchaser_id", null: false
    t.uuid "holder_id"
    t.string "qr_token", null: false
    t.string "invite_token"
    t.string "invited_email"
    t.datetime "invited_at"
    t.string "status", default: "pending_payment", null: false
    t.datetime "checked_in_at"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["booking_id", "position"], name: "index_ticket_entitlements_on_booking_id_and_position"
    t.index ["booking_id"], name: "index_ticket_entitlements_on_booking_id"
    t.index ["event_ticket_type_id"], name: "index_ticket_entitlements_on_event_ticket_type_id"
    t.index ["holder_id"], name: "index_ticket_entitlements_on_holder_id"
    t.index ["invite_token"], name: "index_ticket_entitlements_on_invite_token", unique: true, where: "(invite_token IS NOT NULL)"
    t.index ["purchaser_id"], name: "index_ticket_entitlements_on_purchaser_id"
    t.index ["qr_token"], name: "index_ticket_entitlements_on_qr_token", unique: true
    t.check_constraint "status::text = ANY (ARRAY['pending_payment'::character varying, 'active'::character varying, 'checked_in'::character varying, 'canceled'::character varying]::text[])", name: "check_ticket_entitlements_status"
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
    t.check_constraint "role::text = ANY (ARRAY['consumer'::character varying, 'artist'::character varying, 'venue_manager'::character varying, 'admin'::character varying, 'brand'::character varying, 'support'::character varying]::text[])", name: "check_role"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'disabled'::character varying::text])", name: "check_status"
  end

  create_table "venue_blocklists", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "venue_id", null: false
    t.uuid "user_id", null: false
    t.uuid "blocked_by_id", null: false
    t.string "reason", null: false
    t.text "description"
    t.string "incident_type"
    t.uuid "related_event_id"
    t.uuid "related_booking_id"
    t.datetime "blocked_until"
    t.boolean "is_permanent", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["blocked_by_id"], name: "index_venue_blocklists_on_blocked_by_id"
    t.index ["is_permanent"], name: "index_venue_blocklists_on_is_permanent"
    t.index ["user_id"], name: "index_venue_blocklists_on_user_id"
    t.index ["venue_id", "user_id"], name: "index_venue_blocklists_on_venue_id_and_user_id"
    t.index ["venue_id"], name: "index_venue_blocklists_on_venue_id"
    t.check_constraint "incident_type IS NULL OR (incident_type::text = ANY (ARRAY['no_show'::character varying::text, 'late_cancellation'::character varying::text, 'behavior'::character varying::text, 'fraud'::character varying::text, 'other'::character varying::text]))", name: "check_venue_blocklist_incident_type"
  end

  create_table "venue_categories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "venue_id", null: false
    t.uuid "category_id", null: false
    t.string "source", default: "manual", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_venue_categories_on_category_id"
    t.index ["venue_id", "category_id"], name: "index_venue_categories_on_venue_id_and_category_id", unique: true
    t.index ["venue_id"], name: "index_venue_categories_on_venue_id"
  end

  create_table "venue_follows", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "venue_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "venue_id"], name: "index_venue_follows_user_venue_unique", unique: true
    t.index ["user_id"], name: "index_venue_follows_on_user_id"
    t.index ["venue_id"], name: "index_venue_follows_on_venue_id"
  end

  create_table "venue_interests", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "venue_id", null: false
    t.string "rsvp_status", default: "yes", null: false
    t.integer "guest_count", default: 0, null: false
    t.text "notes"
    t.datetime "responded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["rsvp_status"], name: "index_venue_interests_on_rsvp_status"
    t.index ["user_id", "venue_id"], name: "index_venue_interests_user_venue_unique", unique: true
    t.index ["user_id"], name: "index_venue_interests_on_user_id"
    t.index ["venue_id"], name: "index_venue_interests_on_venue_id"
    t.check_constraint "rsvp_status::text = ANY (ARRAY['yes'::character varying::text, 'no'::character varying::text, 'maybe'::character varying::text])", name: "check_venue_rsvp_status"
  end

  create_table "venue_menu_categories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "venue_menu_id", null: false
    t.string "name", null: false
    t.text "description"
    t.string "category_type"
    t.integer "display_order", default: 0, null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["venue_menu_id", "display_order"], name: "index_venue_menu_categories_on_venue_menu_id_and_display_order"
    t.index ["venue_menu_id"], name: "index_venue_menu_categories_on_venue_menu_id"
  end

  create_table "venue_menu_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "venue_menu_category_id", null: false
    t.string "name", null: false
    t.text "description"
    t.decimal "price", precision: 10, scale: 2, null: false
    t.string "currency", default: "USD", null: false
    t.string "item_type"
    t.string "image_url"
    t.boolean "is_available", default: true, null: false
    t.boolean "is_vegetarian", default: false
    t.boolean "is_vegan", default: false
    t.boolean "is_gluten_free", default: false
    t.boolean "contains_alcohol", default: false
    t.text "allergens", default: [], array: true
    t.text "dietary_info"
    t.text "ingredients"
    t.integer "preparation_time_minutes"
    t.integer "display_order", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_available"], name: "index_venue_menu_items_on_is_available"
    t.index ["venue_menu_category_id", "display_order"], name: "idx_on_venue_menu_category_id_display_order_777af76459"
    t.index ["venue_menu_category_id"], name: "index_venue_menu_items_on_venue_menu_category_id"
    t.check_constraint "price >= 0::numeric", name: "check_venue_menu_item_price"
  end

  create_table "venue_menus", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "venue_id", null: false
    t.string "name", null: false
    t.string "menu_type", null: false
    t.text "description"
    t.boolean "is_active", default: true, null: false
    t.datetime "available_from"
    t.datetime "available_until"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_active"], name: "index_venue_menus_on_is_active"
    t.index ["menu_type"], name: "index_venue_menus_on_menu_type"
    t.index ["venue_id"], name: "index_venue_menus_on_venue_id"
    t.check_constraint "menu_type::text = ANY (ARRAY['food'::character varying::text, 'bar'::character varying::text, 'both'::character varying::text])", name: "check_venue_menu_type"
  end

  create_table "venue_pr_partnerships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "venue_id", null: false
    t.uuid "user_id", null: false
    t.string "role", default: "master_pr", null: false
    t.string "status", default: "active", null: false
    t.datetime "ended_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "status"], name: "index_venue_pr_partnerships_on_user_and_status"
    t.index ["user_id"], name: "index_venue_pr_partnerships_on_user_id"
    t.index ["venue_id", "user_id"], name: "index_venue_pr_partnerships_active_venue_user", unique: true, where: "((status)::text = 'active'::text)"
    t.index ["venue_id"], name: "index_venue_pr_partnerships_active_master_per_venue", unique: true, where: "(((status)::text = 'active'::text) AND ((role)::text = 'master_pr'::text))"
    t.index ["venue_id"], name: "index_venue_pr_partnerships_on_venue_id"
  end

  create_table "venue_staff", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "venue_id", null: false
    t.uuid "user_id", null: false
    t.string "role", default: "waiter", null: false
    t.string "status", default: "active", null: false
    t.boolean "receives_notifications", default: true, null: false
    t.decimal "current_latitude", precision: 10, scale: 7
    t.decimal "current_longitude", precision: 10, scale: 7
    t.datetime "last_location_update"
    t.datetime "shift_start_at"
    t.datetime "shift_end_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["role"], name: "index_venue_staff_on_role"
    t.index ["status"], name: "index_venue_staff_on_status"
    t.index ["user_id"], name: "index_venue_staff_on_user_id"
    t.index ["venue_id", "user_id"], name: "index_venue_staff_on_venue_id_and_user_id", unique: true
    t.index ["venue_id"], name: "index_venue_staff_on_venue_id"
    t.check_constraint "role::text = ANY (ARRAY['waiter'::character varying::text, 'bartender'::character varying::text, 'chef'::character varying::text, 'manager'::character varying::text, 'host'::character varying::text])", name: "check_venue_staff_role"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'on_break'::character varying::text, 'off_duty'::character varying::text, 'inactive'::character varying::text])", name: "check_venue_staff_status"
  end

  create_table "venues", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "owner_id", null: false
    t.string "name", null: false
    t.text "description"
    t.string "address1"
    t.string "address2"
    t.string "city", null: false
    t.string "region"
    t.string "country", null: false
    t.string "postal_code"
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "longitude", precision: 10, scale: 7
    t.integer "capacity"
    t.string "contact_email"
    t.string "contact_phone", limit: 20
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "default_currency", default: "USD", null: false
    t.boolean "rsvp_enabled", default: true, null: false
    t.index ["city"], name: "index_venues_on_city"
    t.index ["latitude", "longitude"], name: "index_venues_on_latitude_and_longitude"
    t.index ["owner_id"], name: "index_venues_on_owner_id"
    t.index ["status"], name: "index_venues_on_status"
    t.check_constraint "capacity IS NULL OR capacity > 0", name: "check_venue_capacity"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'inactive'::character varying::text])", name: "check_venue_status"
  end

  create_table "vibe_checks", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "event_id", null: false
    t.uuid "user_id", null: false
    t.uuid "booking_id"
    t.integer "overall_rating", null: false
    t.integer "atmosphere_rating"
    t.integer "music_rating"
    t.integer "crowd_rating"
    t.integer "service_rating"
    t.integer "value_rating"
    t.text "review"
    t.text "highlights"
    t.text "lowlights"
    t.boolean "would_return", default: true
    t.boolean "would_recommend", default: true
    t.string "status", default: "published", null: false
    t.integer "helpful_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["booking_id"], name: "index_vibe_checks_on_booking_id"
    t.index ["created_at"], name: "index_vibe_checks_on_created_at"
    t.index ["event_id", "user_id"], name: "index_vibe_checks_on_event_id_and_user_id", unique: true
    t.index ["event_id"], name: "index_vibe_checks_on_event_id"
    t.index ["overall_rating"], name: "index_vibe_checks_on_overall_rating"
    t.index ["status"], name: "index_vibe_checks_on_status"
    t.index ["user_id"], name: "index_vibe_checks_on_user_id"
    t.check_constraint "atmosphere_rating IS NULL OR atmosphere_rating >= 1 AND atmosphere_rating <= 5", name: "check_vibecheck_atmosphere_rating"
    t.check_constraint "crowd_rating IS NULL OR crowd_rating >= 1 AND crowd_rating <= 5", name: "check_vibecheck_crowd_rating"
    t.check_constraint "music_rating IS NULL OR music_rating >= 1 AND music_rating <= 5", name: "check_vibecheck_music_rating"
    t.check_constraint "overall_rating >= 1 AND overall_rating <= 5", name: "check_vibecheck_overall_rating"
    t.check_constraint "service_rating IS NULL OR service_rating >= 1 AND service_rating <= 5", name: "check_vibecheck_service_rating"
    t.check_constraint "status::text = ANY (ARRAY['published'::character varying::text, 'hidden'::character varying::text, 'flagged'::character varying::text])", name: "check_vibecheck_status"
    t.check_constraint "value_rating IS NULL OR value_rating >= 1 AND value_rating <= 5", name: "check_vibecheck_value_rating"
  end

  create_table "waiter_calls", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "event_id", null: false
    t.uuid "user_id", null: false
    t.uuid "booking_id"
    t.uuid "order_id"
    t.string "call_type", default: "assistance", null: false
    t.text "message"
    t.string "status", default: "pending", null: false
    t.uuid "assigned_staff_id"
    t.decimal "user_latitude", precision: 10, scale: 7
    t.decimal "user_longitude", precision: 10, scale: 7
    t.string "table_number"
    t.string "location_description"
    t.datetime "acknowledged_at"
    t.datetime "completed_at"
    t.datetime "canceled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assigned_staff_id"], name: "index_waiter_calls_on_assigned_staff_id"
    t.index ["booking_id"], name: "index_waiter_calls_on_booking_id"
    t.index ["call_type"], name: "index_waiter_calls_on_call_type"
    t.index ["created_at"], name: "index_waiter_calls_on_created_at"
    t.index ["event_id"], name: "index_waiter_calls_on_event_id"
    t.index ["order_id"], name: "index_waiter_calls_on_order_id"
    t.index ["status"], name: "index_waiter_calls_on_status"
    t.index ["user_id"], name: "index_waiter_calls_on_user_id"
    t.check_constraint "call_type::text = ANY (ARRAY['assistance'::character varying::text, 'order_help'::character varying::text, 'bill_request'::character varying::text, 'complaint'::character varying::text, 'emergency'::character varying::text])", name: "check_waiter_call_type"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'acknowledged'::character varying::text, 'in_progress'::character varying::text, 'completed'::character varying::text, 'canceled'::character varying::text])", name: "check_waiter_call_status"
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
  add_foreign_key "bill_splits", "food_bar_orders", on_delete: :cascade
  add_foreign_key "bill_splits", "payment_transactions", on_delete: :nullify
  add_foreign_key "bill_splits", "users", on_delete: :nullify
  add_foreign_key "booking_ticket_lines", "bookings", on_delete: :cascade
  add_foreign_key "booking_ticket_lines", "event_ticket_types", on_delete: :restrict
  add_foreign_key "bookings", "events"
  add_foreign_key "bookings", "payment_transactions", on_delete: :nullify
  add_foreign_key "bookings", "promo_codes", on_delete: :nullify
  add_foreign_key "bookings", "users"
  add_foreign_key "bookings", "users", column: "assigned_by_id", on_delete: :nullify
  add_foreign_key "bookings", "users", column: "cancellation_approved_by_id", on_delete: :nullify
  add_foreign_key "categories", "categories_groups", on_delete: :cascade
  add_foreign_key "chat_messages", "chat_messages", column: "reply_to_id", on_delete: :nullify
  add_foreign_key "chat_messages", "chats", on_delete: :cascade
  add_foreign_key "chat_messages", "users", column: "sender_id", on_delete: :cascade
  add_foreign_key "chats", "users", column: "user1_id", on_delete: :cascade
  add_foreign_key "chats", "users", column: "user2_id", on_delete: :cascade
  add_foreign_key "crypto_wallets", "users", on_delete: :cascade
  add_foreign_key "devices", "users"
  add_foreign_key "event_artists", "events", on_delete: :cascade
  add_foreign_key "event_artists", "users", column: "artist_id", on_delete: :cascade
  add_foreign_key "event_boosts", "events"
  add_foreign_key "event_boosts", "users", column: "created_by_id"
  add_foreign_key "event_categories", "categories", on_delete: :cascade
  add_foreign_key "event_categories", "events", on_delete: :cascade
  add_foreign_key "event_custom_categories", "events"
  add_foreign_key "event_interests", "events"
  add_foreign_key "event_interests", "users"
  add_foreign_key "event_menus", "events", on_delete: :cascade
  add_foreign_key "event_posts", "events", on_delete: :cascade
  add_foreign_key "event_posts", "users", on_delete: :cascade
  add_foreign_key "event_reports", "events"
  add_foreign_key "event_reports", "users", column: "reporter_id"
  add_foreign_key "event_reports", "users", column: "reviewed_by_id"
  add_foreign_key "event_ticket_types", "events", on_delete: :cascade
  add_foreign_key "events", "users", column: "blocked_by_id"
  add_foreign_key "events", "users", column: "creator_id"
  add_foreign_key "events", "venues"
  add_foreign_key "floor_plan_elements", "floor_plans", on_delete: :cascade
  add_foreign_key "floor_plan_zones", "floor_plans", on_delete: :cascade
  add_foreign_key "floor_plans", "venues", on_delete: :cascade
  add_foreign_key "follow_requests", "users", column: "requested_id", on_delete: :cascade
  add_foreign_key "follow_requests", "users", column: "requester_id", on_delete: :cascade
  add_foreign_key "follows", "users", column: "follower_id", on_delete: :cascade
  add_foreign_key "follows", "users", column: "following_id", on_delete: :cascade
  add_foreign_key "food_bar_order_items", "food_bar_orders", on_delete: :cascade
  add_foreign_key "food_bar_order_items", "menu_items", on_delete: :restrict
  add_foreign_key "food_bar_orders", "bookings", on_delete: :nullify
  add_foreign_key "food_bar_orders", "events", on_delete: :cascade
  add_foreign_key "food_bar_orders", "payment_transactions", on_delete: :nullify
  add_foreign_key "food_bar_orders", "users", on_delete: :cascade
  add_foreign_key "group_chat_memberships", "group_chats", on_delete: :cascade
  add_foreign_key "group_chat_memberships", "users", on_delete: :cascade
  add_foreign_key "group_chat_messages", "group_chat_messages", column: "forwarded_from_id", on_delete: :nullify
  add_foreign_key "group_chat_messages", "group_chat_messages", column: "reply_to_id", on_delete: :nullify
  add_foreign_key "group_chat_messages", "group_chats", on_delete: :cascade
  add_foreign_key "group_chat_messages", "users", on_delete: :cascade
  add_foreign_key "group_chats", "users", column: "created_by_id", on_delete: :restrict
  add_foreign_key "likes", "users"
  add_foreign_key "live_streams", "events"
  add_foreign_key "live_streams", "venues"
  add_foreign_key "menu_categories", "event_menus", on_delete: :cascade
  add_foreign_key "menu_items", "menu_categories", on_delete: :cascade
  add_foreign_key "moments", "events"
  add_foreign_key "moments", "users"
  add_foreign_key "moments", "venues"
  add_foreign_key "notifications", "users", on_delete: :cascade
  add_foreign_key "otps", "users"
  add_foreign_key "payment_methods", "users", on_delete: :cascade
  add_foreign_key "payment_transactions", "users", on_delete: :restrict
  add_foreign_key "payment_transactions", "wallets", on_delete: :restrict
  add_foreign_key "promo_codes", "events", on_delete: :nullify
  add_foreign_key "promo_codes", "venues"
  add_foreign_key "ratings", "users"
  add_foreign_key "seats", "tables", on_delete: :cascade
  add_foreign_key "split_qr_codes", "food_bar_orders", on_delete: :cascade
  add_foreign_key "stream_views", "live_streams"
  add_foreign_key "stream_views", "users"
  add_foreign_key "tables", "floor_plan_zones", on_delete: :cascade
  add_foreign_key "ticket_entitlements", "bookings", on_delete: :cascade
  add_foreign_key "ticket_entitlements", "event_ticket_types", on_delete: :restrict
  add_foreign_key "ticket_entitlements", "users", column: "holder_id"
  add_foreign_key "ticket_entitlements", "users", column: "purchaser_id"
  add_foreign_key "user_blocks", "users", column: "blocked_id", on_delete: :cascade
  add_foreign_key "user_blocks", "users", column: "blocker_id", on_delete: :cascade
  add_foreign_key "user_deactivations", "users", on_delete: :cascade
  add_foreign_key "user_reports", "users", column: "reported_id", on_delete: :cascade
  add_foreign_key "user_reports", "users", column: "reporter_id", on_delete: :cascade
  add_foreign_key "user_reports", "users", column: "reviewed_by_id", on_delete: :nullify
  add_foreign_key "venue_blocklists", "bookings", column: "related_booking_id", on_delete: :nullify
  add_foreign_key "venue_blocklists", "events", column: "related_event_id", on_delete: :nullify
  add_foreign_key "venue_blocklists", "users", column: "blocked_by_id", on_delete: :nullify
  add_foreign_key "venue_blocklists", "users", on_delete: :cascade
  add_foreign_key "venue_blocklists", "venues", on_delete: :cascade
  add_foreign_key "venue_categories", "categories", on_delete: :cascade
  add_foreign_key "venue_categories", "venues", on_delete: :cascade
  add_foreign_key "venue_follows", "users", on_delete: :cascade
  add_foreign_key "venue_follows", "venues", on_delete: :cascade
  add_foreign_key "venue_interests", "users", on_delete: :cascade
  add_foreign_key "venue_interests", "venues", on_delete: :cascade
  add_foreign_key "venue_menu_categories", "venue_menus", on_delete: :cascade
  add_foreign_key "venue_menu_items", "venue_menu_categories", on_delete: :cascade
  add_foreign_key "venue_menus", "venues", on_delete: :cascade
  add_foreign_key "venue_pr_partnerships", "users"
  add_foreign_key "venue_pr_partnerships", "venues"
  add_foreign_key "venue_staff", "users", on_delete: :cascade
  add_foreign_key "venue_staff", "venues", on_delete: :cascade
  add_foreign_key "venues", "users", column: "owner_id"
  add_foreign_key "vibe_checks", "bookings", on_delete: :nullify
  add_foreign_key "vibe_checks", "events", on_delete: :cascade
  add_foreign_key "vibe_checks", "users", on_delete: :cascade
  add_foreign_key "waiter_calls", "bookings", on_delete: :nullify
  add_foreign_key "waiter_calls", "events", on_delete: :cascade
  add_foreign_key "waiter_calls", "food_bar_orders", column: "order_id", on_delete: :nullify
  add_foreign_key "waiter_calls", "users", on_delete: :cascade
  add_foreign_key "waiter_calls", "venue_staff", column: "assigned_staff_id", on_delete: :nullify
  add_foreign_key "wallets", "users", on_delete: :cascade
end
