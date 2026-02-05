# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2026_02_03_060328) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "btree_gist"
  enable_extension "plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.integer "code"
    t.string "name"
    t.string "network"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.integer "record_id", null: false
    t.integer "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "appointments", force: :cascade do |t|
    t.bigint "member_id", null: false
    t.bigint "role_id", null: false
    t.bigint "organization_id"
    t.bigint "county_id"
    t.daterange "period", null: false
    t.integer "start_precision", default: 0, null: false
    t.integer "end_precision", default: 0, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index "member_id, role_id, COALESCE(organization_id, (0)::bigint), COALESCE(county_id, (0)::bigint), period", name: "appointments_no_overlap", using: :gist
    t.index ["county_id"], name: "index_appointments_on_county_id"
    t.index ["member_id"], name: "index_appointments_on_member_id"
    t.index ["organization_id"], name: "index_appointments_on_organization_id"
    t.index ["period"], name: "index_appointments_on_period", using: :gist
    t.index ["role_id"], name: "index_appointments_on_role_id"
  end

  create_table "arrests", force: :cascade do |t|
    t.integer "event_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["event_id"], name: "index_arrests_on_event_id"
  end

  create_table "arrests_organizations", force: :cascade do |t|
    t.integer "arrest_id"
    t.integer "organization_id"
    t.index ["arrest_id"], name: "index_arrests_organizations_on_arrest_id"
    t.index ["organization_id"], name: "index_arrests_organizations_on_organization_id"
  end

  create_table "audit_users_changes", force: :cascade do |t|
    t.datetime "changed_at", default: -> { "now()" }
    t.text "action"
    t.text "db_user"
    t.inet "client_addr"
    t.jsonb "old_row"
    t.jsonb "new_row"
  end

  create_table "auth_events", force: :cascade do |t|
    t.integer "user_id"
    t.string "event_type", null: false
    t.string "ip"
    t.text "user_agent"
    t.text "metadata"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["created_at"], name: "index_auth_events_on_created_at"
    t.index ["event_type"], name: "index_auth_events_on_event_type"
    t.index ["user_id"], name: "index_auth_events_on_user_id"
  end

  create_table "cities", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "code"
    t.integer "county_id"
    t.integer "core_county_id"
    t.index ["county_id"], name: "index_cities_on_county_id"
  end

  create_table "cookies", force: :cascade do |t|
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.text "data"
    t.integer "quarter_id"
    t.string "category"
    t.bigint "year_id"
    t.index ["quarter_id"], name: "index_cookies_on_quarter_id"
    t.index ["year_id"], name: "index_cookies_on_year_id"
  end

  create_table "counties", force: :cascade do |t|
    t.string "name"
    t.string "code"
    t.integer "population"
    t.integer "state_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "full_code"
    t.integer "city_id"
    t.string "shortname"
    t.boolean "destination"
    t.text "comparison"
    t.index ["city_id"], name: "index_counties_on_city_id"
    t.index ["state_id"], name: "index_counties_on_state_id"
  end

  create_table "detentions", force: :cascade do |t|
    t.integer "event_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "legacy_id"
    t.index ["event_id"], name: "index_detentions_on_event_id"
  end

  create_table "detentions_organizations", force: :cascade do |t|
    t.integer "detention_id"
    t.integer "organization_id"
    t.index ["detention_id"], name: "index_detentions_organizations_on_detention_id"
    t.index ["organization_id"], name: "index_detentions_organizations_on_organization_id"
  end

  create_table "divisions", force: :cascade do |t|
    t.string "name"
    t.string "description"
    t.integer "scian3"
    t.integer "sector_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "shortname"
    t.index ["sector_id"], name: "index_divisions_on_sector_id"
  end

  create_table "divisions_organizations", id: false, force: :cascade do |t|
    t.integer "division_id"
    t.integer "organization_id"
    t.index ["division_id"], name: "index_divisions_organizations_on_division_id"
    t.index ["organization_id"], name: "index_divisions_organizations_on_organization_id"
  end

  create_table "events", force: :cascade do |t|
    t.datetime "event_date"
    t.integer "town_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "month_id"
    t.integer "organization_id"
    t.index ["month_id"], name: "index_events_on_month_id"
    t.index ["organization_id"], name: "index_events_on_organization_id"
    t.index ["town_id"], name: "index_events_on_town_id"
  end

  create_table "events_sources", id: false, force: :cascade do |t|
    t.integer "event_id"
    t.integer "source_id"
  end

  create_table "fake_identities", force: :cascade do |t|
    t.string "firstname"
    t.string "lastname1"
    t.string "lastname2"
    t.bigint "member_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["member_id"], name: "index_fake_identities_on_member_id"
  end

  create_table "hits", force: :cascade do |t|
    t.date "date"
    t.string "title"
    t.string "link"
    t.bigint "town_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "legacy_id"
    t.string "report"
    t.boolean "national"
    t.boolean "protected_link", default: false, null: false
    t.bigint "user_id"
    t.index ["town_id"], name: "index_hits_on_town_id"
    t.index ["user_id"], name: "index_hits_on_user_id"
  end

  create_table "hits_members", id: false, force: :cascade do |t|
    t.bigint "hit_id", null: false
    t.bigint "member_id", null: false
    t.index ["hit_id", "member_id"], name: "index_hits_members_on_hit_id_and_member_id"
    t.index ["member_id", "hit_id"], name: "index_hits_members_on_member_id_and_hit_id"
  end

  create_table "keys", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.text "key"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["user_id"], name: "index_keys_on_user_id"
  end

  create_table "killings", force: :cascade do |t|
    t.integer "legacy_id"
    t.integer "killed_count"
    t.integer "wounded_count"
    t.integer "killers_count"
    t.integer "arrested_count"
    t.string "type_of_place"
    t.boolean "mass_grave"
    t.boolean "fire_weapon"
    t.boolean "white_weapon"
    t.boolean "aggression"
    t.boolean "shooting_between_criminals_and_authorities"
    t.string "notes"
    t.integer "event_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "legacy_number"
    t.integer "aggresor_count"
    t.integer "kidnapped_count"
    t.integer "killer_vehicle_count"
    t.boolean "car_chase"
    t.boolean "shooting_among_criminals"
    t.string "message"
    t.boolean "shooting"
    t.boolean "any_shooting"
    t.index ["event_id"], name: "index_killings_on_event_id"
  end

  create_table "leads", force: :cascade do |t|
    t.string "category"
    t.integer "event_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "legacy_id"
    t.index ["event_id"], name: "index_leads_on_event_id"
  end

  create_table "leagues", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "lrvl_documents", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "file", limit: 255, null: false
    t.string "title", limit: 255, null: false
    t.text "description", null: false
    t.string "url", limit: 255
    t.datetime "created_at", precision: 0
    t.datetime "updated_at", precision: 0
    t.datetime "deleted_at", precision: 0
    t.integer "only_vip", limit: 2, default: 0, null: false
  end

  create_table "lrvl_failed_jobs", force: :cascade do |t|
    t.text "connection", null: false
    t.text "queue", null: false
    t.text "payload", null: false
    t.text "exception", null: false
    t.datetime "failed_at", precision: 0, default: -> { "CURRENT_TIMESTAMP" }, null: false
  end

  create_table "lrvl_graph_reports", force: :cascade do |t|
    t.string "name", limit: 255, null: false
    t.text "url", null: false
    t.boolean "enabled_home", default: true, null: false
    t.boolean "enabled_datos", default: true, null: false
    t.datetime "created_at", precision: 0
    t.datetime "updated_at", precision: 0
    t.datetime "deleted_at", precision: 0
  end

  create_table "lrvl_internal_publications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "cover", limit: 255
    t.string "title", limit: 255, null: false
    t.text "description", null: false
    t.string "url", limit: 255
    t.datetime "created_at", precision: 0
    t.datetime "updated_at", precision: 0
    t.datetime "deleted_at", precision: 0
  end

  create_table "lrvl_log_membership_payments", force: :cascade do |t|
    t.string "who", limit: 255, null: false
    t.string "event", limit: 255, null: false
    t.text "event_data", null: false
    t.datetime "created_at", precision: 0
    t.datetime "updated_at", precision: 0
  end

  create_table "lrvl_membership_expiration", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "membership_id", null: false
    t.string "customer_token", limit: 255, null: false
    t.bigint "log_membership_payments_id", null: false
    t.datetime "expiration", precision: 0, null: false
    t.datetime "created_at", precision: 0
    t.datetime "updated_at", precision: 0
    t.boolean "expirated", default: false, null: false
  end

  create_table "lrvl_memberships", force: :cascade do |t|
    t.string "name", limit: 255, null: false
    t.text "description", null: false
    t.integer "duration", limit: 2, default: 30, null: false
    t.float "price", null: false
    t.datetime "created_at", precision: 0
    t.datetime "updated_at", precision: 0
    t.float "price_year", default: 0.0, null: false
    t.integer "duration_year", default: 365, null: false
  end

  create_table "lrvl_news", force: :cascade do |t|
    t.bigint "referer_id", null: false
    t.bigint "user_id", null: false
    t.string "cover", limit: 255, null: false
    t.string "title", limit: 255, null: false
    t.text "description", null: false
    t.string "url", limit: 255, null: false
    t.datetime "published", precision: 0, null: false
    t.datetime "created_at", precision: 0
    t.datetime "updated_at", precision: 0
    t.datetime "deleted_at", precision: 0
  end

  create_table "lrvl_password_resets", id: false, force: :cascade do |t|
    t.string "email", limit: 255, null: false
    t.string "token", limit: 255, null: false
    t.datetime "created_at", precision: 0
    t.index ["email"], name: "lrvl_password_resets_email_index"
  end

  create_table "lrvl_payments", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.text "products", null: false
    t.string "total", limit: 255, null: false
    t.string "reference", limit: 255
    t.integer "msi", default: 0, null: false
    t.string "gateway", limit: 255
    t.text "gatewayData"
    t.integer "status", limit: 2, default: 1, null: false
    t.datetime "created_at", precision: 0
    t.datetime "updated_at", precision: 0
    t.datetime "deleted_at", precision: 0
  end

  create_table "lrvl_publications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "cover", limit: 255
    t.string "title", limit: 255, null: false
    t.text "description", null: false
    t.string "url", limit: 255, null: false
    t.datetime "created_at", precision: 0
    t.datetime "updated_at", precision: 0
    t.datetime "deleted_at", precision: 0
  end

  create_table "lrvl_user_conekta_customers", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "customer_token", limit: 255, null: false
    t.text "customer_data", null: false
    t.string "subscription_id", limit: 255, null: false
    t.text "subscription_data"
    t.string "random_key", limit: 255, null: false
    t.datetime "created_at", precision: 0
    t.datetime "updated_at", precision: 0
    t.text "cancelation_data"
    t.boolean "canceled", default: false
  end

  create_table "lrvl_videos", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title", limit: 255, null: false
    t.text "description"
    t.text "url", null: false
    t.datetime "created_at", precision: 0
    t.datetime "updated_at", precision: 0
    t.datetime "deleted_at", precision: 0
  end

  create_table "member_relationships", force: :cascade do |t|
    t.bigint "member_a_id", null: false
    t.bigint "member_b_id", null: false
    t.string "role_a", null: false
    t.string "role_b", null: false
    t.text "notes"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "role_a_gender"
    t.string "role_b_gender"
    t.index ["member_a_id", "member_b_id", "role_a", "role_b"], name: "index_member_relationships_uniqueness", unique: true
    t.index ["member_a_id"], name: "index_member_relationships_on_member_a_id"
    t.index ["member_b_id"], name: "index_member_relationships_on_member_b_id"
  end

  create_table "members", force: :cascade do |t|
    t.string "firstname"
    t.string "lastname1"
    t.string "lastname2"
    t.string "rfc"
    t.date "birthday"
    t.string "gender"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "organization_id"
    t.integer "role_id"
    t.string "mail"
    t.text "alias"
    t.integer "arrest_id"
    t.integer "detention_id"
    t.bigint "member_id"
    t.boolean "media_score"
    t.date "start_date"
    t.date "end_date"
    t.integer "criminal_link_id"
    t.boolean "involved"
    t.boolean "birthday_aprox", default: false
    t.index ["arrest_id"], name: "index_members_on_arrest_id"
    t.index ["detention_id"], name: "index_members_on_detention_id"
    t.index ["member_id"], name: "index_members_on_member_id"
    t.index ["organization_id"], name: "index_members_on_organization_id"
    t.index ["role_id"], name: "index_members_on_role_id"
  end

  create_table "members_notes", id: false, force: :cascade do |t|
    t.bigint "member_id", null: false
    t.bigint "note_id", null: false
  end

  create_table "migrations", id: :serial, force: :cascade do |t|
    t.string "migration", limit: 255, null: false
    t.integer "batch", null: false
  end

  create_table "months", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "quarter_id", null: false
    t.datetime "first_day"
    t.index ["quarter_id"], name: "index_months_on_quarter_id"
  end

  create_table "names", force: :cascade do |t|
    t.string "word"
    t.integer "freq"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "notes", force: :cascade do |t|
    t.text "story"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "organization_towns", force: :cascade do |t|
    t.integer "town_id"
    t.integer "organization_id"
    t.index ["organization_id"], name: "index_organization_towns_on_organization_id"
    t.index ["town_id"], name: "index_organization_towns_on_town_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "name"
    t.string "acronym"
    t.boolean "legal"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "rfc"
    t.integer "county_id"
    t.string "domain"
    t.boolean "active_links"
    t.date "active_since"
    t.string "league"
    t.string "subleague"
    t.integer "legacy_id"
    t.integer "parent_id"
    t.text "allies"
    t.text "rivals"
    t.text "origin"
    t.text "alias"
    t.boolean "active"
    t.integer "subleague_id"
    t.integer "mainleague_id"
    t.string "legacy_names"
    t.string "coalition"
    t.string "color"
    t.string "group"
    t.text "ip_address"
    t.boolean "designation", default: false, null: false
    t.date "designation_date"
    t.boolean "search_panel", default: false, null: false
    t.integer "search_level"
    t.bigint "criminal_link_id"
    t.boolean "data_access"
    t.datetime "subscription_started_at"
    t.index ["county_id"], name: "index_organizations_on_county_id"
    t.index ["criminal_link_id"], name: "index_organizations_on_criminal_link_id"
  end

  create_table "organizations_towns", force: :cascade do |t|
    t.integer "town_id"
    t.integer "organization_id"
    t.index ["organization_id"], name: "index_organizations_towns_on_organization_id"
    t.index ["town_id"], name: "index_organizations_towns_on_town_id"
  end

  create_table "plans", force: :cascade do |t|
    t.string "name", null: false
    t.integer "level", null: false
    t.integer "duration_days", default: 30, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["level"], name: "index_plans_on_level", unique: true
  end

  create_table "posts", force: :cascade do |t|
    t.datetime "publication"
    t.string "content"
    t.string "hashtags"
    t.integer "likes"
    t.integer "shares"
    t.boolean "is_quote"
    t.boolean "is_retweet"
    t.string "url"
    t.integer "account_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["account_id"], name: "index_posts_on_account_id"
  end

  create_table "quarters", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "year_id"
    t.datetime "first_day"
    t.index ["year_id"], name: "index_quarters_on_year_id"
  end

  create_table "queries", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "member_id", null: false
    t.bigint "organization_id", null: false
    t.float "homo_score"
    t.string "firstname"
    t.string "lastname1"
    t.string "lastname2"
    t.text "outcome"
    t.integer "search"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "source"
    t.integer "status_code"
    t.boolean "success", default: true, null: false
    t.string "request_id"
    t.integer "result_count"
    t.string "query_label"
    t.datetime "dataset_last_updated_at"
    t.text "firstname_ciphertext"
    t.text "lastname1_ciphertext"
    t.text "lastname2_ciphertext"
    t.text "query_label_ciphertext"
    t.text "outcome_ciphertext"
    t.string "query_label_bidx"
    t.index ["member_id"], name: "index_queries_on_member_id"
    t.index ["organization_id"], name: "index_queries_on_organization_id"
    t.index ["query_label_bidx"], name: "index_queries_on_query_label_bidx"
    t.index ["request_id"], name: "index_queries_on_request_id"
    t.index ["source"], name: "index_queries_on_source"
    t.index ["success"], name: "index_queries_on_success"
    t.index ["user_id"], name: "index_queries_on_user_id"
  end

  create_table "roles", force: :cascade do |t|
    t.string "name"
    t.string "description"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.boolean "former"
    t.boolean "criminal"
  end

  create_table "sectors", force: :cascade do |t|
    t.string "name"
    t.string "description"
    t.integer "scian2"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "sources", force: :cascade do |t|
    t.datetime "publication"
    t.string "media_type"
    t.string "url"
    t.boolean "is_post"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "member_id"
    t.index ["member_id"], name: "index_sources_on_member_id"
  end

  create_table "states", force: :cascade do |t|
    t.string "name"
    t.string "shortname"
    t.string "code"
    t.integer "population"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.text "ensu_cities"
    t.text "comparison"
    t.integer "capital_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "plan_id", null: false
    t.datetime "current_period_end", null: false
    t.string "status", default: "active", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["plan_id"], name: "index_subscriptions_on_plan_id"
    t.index ["user_id", "status"], name: "index_subscriptions_on_user_id_and_status"
    t.index ["user_id"], name: "index_subscriptions_on_user_id"
  end

  create_table "titles", force: :cascade do |t|
    t.string "legacy_id"
    t.string "type"
    t.string "profesion"
    t.bigint "member_id", null: false
    t.bigint "organization_id", null: false
    t.bigint "year_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["member_id"], name: "index_titles_on_member_id"
    t.index ["organization_id"], name: "index_titles_on_organization_id"
    t.index ["year_id"], name: "index_titles_on_year_id"
  end

  create_table "towns", force: :cascade do |t|
    t.string "code"
    t.string "full_code"
    t.string "name"
    t.integer "county_id", null: false
    t.string "urban"
    t.integer "population"
    t.integer "height"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "zip_code"
    t.string "settlement_type"
    t.float "latitude"
    t.float "longitude"
    t.index ["county_id"], name: "index_towns_on_county_id"
  end

  create_table "towns_and_organizations", force: :cascade do |t|
    t.integer "town_id"
    t.integer "organization_id"
    t.index ["organization_id"], name: "index_towns_and_organizations_on_organization_id"
    t.index ["town_id"], name: "index_towns_and_organizations_on_town_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "mail"
    t.string "mobile_phone"
    t.string "other_phone"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "member_id"
    t.string "password_digest"
    t.string "recovery_password_digest"
    t.integer "query_counter"
    t.string "remember_token"
    t.datetime "email_verified_at"
    t.integer "role_id"
    t.boolean "victim_help", default: true
    t.boolean "organization_help", default: true
    t.boolean "index_help", default: true
    t.integer "membership_type"
    t.string "country"
    t.integer "active", default: 1
    t.boolean "promo"
    t.integer "downloads", default: 0
    t.boolean "victim_access", default: true
    t.boolean "organization_access", default: true
    t.boolean "detention_access", default: true
    t.boolean "irco_access", default: true
    t.boolean "icon_access", default: true
    t.string "reset_password_token_digest"
    t.datetime "reset_password_sent_at"
    t.string "session_version"
    t.integer "failed_login_attempts", default: 0, null: false
    t.datetime "locked_until"
    t.string "email_verification_digest"
    t.datetime "email_verification_sent_at"
    t.string "mfa_totp_secret"
    t.datetime "mfa_enabled_at"
    t.text "mfa_backup_codes_digest"
    t.integer "mfa_last_used_step"
    t.string "api_key"
    t.datetime "email_verification_token_used_at"
    t.string "email_verification_token_digest"
    t.index ["api_key"], name: "index_users_on_api_key", unique: true
    t.index ["email_verification_digest"], name: "index_users_on_email_verification_digest"
    t.index ["email_verification_token_digest"], name: "index_users_on_email_verification_token_digest", unique: true
    t.index ["locked_until"], name: "index_users_on_locked_until"
    t.index ["member_id"], name: "index_users_on_member_id"
    t.index ["mfa_enabled_at"], name: "index_users_on_mfa_enabled_at"
    t.index ["reset_password_token_digest"], name: "index_users_on_reset_password_token_digest", unique: true
    t.index ["session_version"], name: "index_users_on_session_version"
  end

  create_table "victims", force: :cascade do |t|
    t.string "firstname"
    t.string "lastname1"
    t.string "lastname2"
    t.string "alias"
    t.string "gender"
    t.integer "age"
    t.integer "age_in_months"
    t.boolean "innocent_bystander"
    t.boolean "reported_cartel_member"
    t.boolean "agressor"
    t.boolean "acuchillado"
    t.boolean "a_golpes"
    t.boolean "asfixiado"
    t.boolean "baleado"
    t.boolean "con_tiro_de_gracia"
    t.boolean "calcinado"
    t.boolean "cinta_adhesiva_en_la_cabeza"
    t.boolean "colgado"
    t.boolean "con_dedos_en_la_boca"
    t.boolean "con_la_lengua_cortada"
    t.boolean "con_mensaje_escrito"
    t.boolean "con_mensaje_escrito_en_el_cuerpo"
    t.boolean "con_senales_de_tortura"
    t.boolean "crucificado"
    t.boolean "decapitado_cabeza_sin_cuerpo"
    t.boolean "decapitado_cuerpo_sin_cabeza"
    t.boolean "degollado"
    t.boolean "descalzo"
    t.boolean "descuartizado"
    t.boolean "desnudo"
    t.boolean "disuelto_en_acido"
    t.boolean "embolsado"
    t.boolean "encobijado"
    t.boolean "enlonado"
    t.boolean "enterrado"
    t.boolean "esposado"
    t.boolean "extraccion_del_globo_ocular"
    t.boolean "hincado"
    t.boolean "manos_atadas_al_frente"
    t.boolean "manos_atadas_atras"
    t.boolean "mutilacion"
    t.boolean "mutilacion_de_genitales"
    t.boolean "mutilacion_de_otra_parte"
    t.boolean "piedra_u_objeto_pesado"
    t.boolean "pies_atados"
    t.boolean "semidesnudo"
    t.boolean "semienterrado"
    t.string "otra_forma"
    t.integer "killing_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "role_id"
    t.integer "organization_id"
    t.string "legacy_name"
    t.string "legacy_role_officer"
    t.string "legacy_role_civil"
    t.index ["killing_id"], name: "index_victims_on_killing_id"
    t.index ["organization_id"], name: "index_victims_on_organization_id"
    t.index ["role_id"], name: "index_victims_on_role_id"
  end

  create_table "years", force: :cascade do |t|
    t.string "name"
    t.datetime "first_day"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "appointments", "counties"
  add_foreign_key "appointments", "members"
  add_foreign_key "appointments", "organizations"
  add_foreign_key "appointments", "roles"
  add_foreign_key "arrests", "events"
  add_foreign_key "cities", "counties"
  add_foreign_key "cities", "counties", column: "core_county_id"
  add_foreign_key "cookies", "quarters"
  add_foreign_key "cookies", "years"
  add_foreign_key "counties", "cities"
  add_foreign_key "counties", "states"
  add_foreign_key "detentions", "events"
  add_foreign_key "divisions", "sectors"
  add_foreign_key "events", "months"
  add_foreign_key "events", "organizations"
  add_foreign_key "events", "towns"
  add_foreign_key "fake_identities", "members"
  add_foreign_key "hits", "towns"
  add_foreign_key "hits", "users", on_delete: :cascade
  add_foreign_key "keys", "users", on_delete: :cascade
  add_foreign_key "killings", "events"
  add_foreign_key "leads", "events"
  add_foreign_key "lrvl_documents", "users", on_delete: :cascade
  add_foreign_key "lrvl_internal_publications", "users", on_delete: :cascade
  add_foreign_key "lrvl_membership_expiration", "lrvl_log_membership_payments", column: "log_membership_payments_id", name: "lrvl_membership_expiration_log_membership_payments_id_foreign"
  add_foreign_key "lrvl_membership_expiration", "lrvl_memberships", column: "membership_id", name: "lrvl_membership_expiration_membership_id_foreign"
  add_foreign_key "lrvl_membership_expiration", "users", on_delete: :cascade
  add_foreign_key "lrvl_news", "users", on_delete: :cascade
  add_foreign_key "lrvl_payments", "users", on_delete: :cascade
  add_foreign_key "lrvl_publications", "users", on_delete: :cascade
  add_foreign_key "lrvl_user_conekta_customers", "users", on_delete: :cascade
  add_foreign_key "lrvl_videos", "users", on_delete: :cascade
  add_foreign_key "member_relationships", "members", column: "member_a_id"
  add_foreign_key "member_relationships", "members", column: "member_b_id"
  add_foreign_key "members", "arrests"
  add_foreign_key "members", "detentions"
  add_foreign_key "members", "members"
  add_foreign_key "members", "organizations"
  add_foreign_key "members", "roles"
  add_foreign_key "months", "quarters"
  add_foreign_key "organizations", "counties"
  add_foreign_key "organizations", "leagues", column: "mainleague_id"
  add_foreign_key "organizations", "leagues", column: "subleague_id"
  add_foreign_key "organizations", "organizations", column: "criminal_link_id"
  add_foreign_key "organizations", "organizations", column: "parent_id"
  add_foreign_key "posts", "accounts"
  add_foreign_key "quarters", "years"
  add_foreign_key "queries", "members"
  add_foreign_key "queries", "organizations"
  add_foreign_key "queries", "users", on_delete: :cascade
  add_foreign_key "sources", "members"
  add_foreign_key "states", "counties", column: "capital_id"
  add_foreign_key "subscriptions", "plans"
  add_foreign_key "subscriptions", "users", on_delete: :cascade
  add_foreign_key "titles", "members"
  add_foreign_key "titles", "organizations"
  add_foreign_key "titles", "years"
  add_foreign_key "towns", "counties"
  add_foreign_key "users", "members"
  add_foreign_key "victims", "killings"
  add_foreign_key "victims", "organizations"
  add_foreign_key "victims", "roles"
end
