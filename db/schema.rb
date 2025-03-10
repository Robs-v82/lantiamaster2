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

ActiveRecord::Schema.define(version: 2024_11_05_154820) do

  # These are extensions that must be enabled in order to support this database
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
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
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

  create_table "cities", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "code"
    t.bigint "county_id"
    t.integer "core_county_id"
    t.index ["county_id"], name: "index_cities_on_county_id"
  end

  create_table "cookies", force: :cascade do |t|
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.text "data"
    t.bigint "quarter_id"
    t.string "category"
    t.bigint "year_id"
    t.index ["quarter_id"], name: "index_cookies_on_quarter_id"
    t.index ["year_id"], name: "index_cookies_on_year_id"
  end

  create_table "counties", force: :cascade do |t|
    t.string "name"
    t.string "code"
    t.integer "population"
    t.bigint "state_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "full_code"
    t.bigint "city_id"
    t.string "shortname"
    t.boolean "destination"
    t.text "comparison"
    t.index ["city_id"], name: "index_counties_on_city_id"
    t.index ["state_id"], name: "index_counties_on_state_id"
  end

  create_table "detentions", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "legacy_id"
    t.index ["event_id"], name: "index_detentions_on_event_id"
  end

  create_table "detentions_organizations", force: :cascade do |t|
    t.bigint "detention_id"
    t.bigint "organization_id"
    t.index ["detention_id"], name: "index_detentions_organizations_on_detention_id"
    t.index ["organization_id"], name: "index_detentions_organizations_on_organization_id"
  end

  create_table "divisions", force: :cascade do |t|
    t.string "name"
    t.string "description"
    t.integer "scian3"
    t.bigint "sector_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "shortname"
    t.index ["sector_id"], name: "index_divisions_on_sector_id"
  end

  create_table "divisions_organizations", id: false, force: :cascade do |t|
    t.bigint "division_id"
    t.bigint "organization_id"
    t.index ["division_id"], name: "index_divisions_organizations_on_division_id"
    t.index ["organization_id"], name: "index_divisions_organizations_on_organization_id"
  end

  create_table "events", force: :cascade do |t|
    t.datetime "event_date"
    t.bigint "town_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "month_id"
    t.bigint "organization_id"
    t.index ["month_id"], name: "index_events_on_month_id"
    t.index ["organization_id"], name: "index_events_on_organization_id"
    t.index ["town_id"], name: "index_events_on_town_id"
  end

  create_table "events_sources", id: false, force: :cascade do |t|
    t.integer "event_id"
    t.integer "source_id"
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
    t.bigint "event_id", null: false
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
    t.bigint "event_id", null: false
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

  create_table "members", force: :cascade do |t|
    t.string "firstname"
    t.string "lastname1"
    t.string "lastname2"
    t.string "rfc"
    t.date "birthday"
    t.string "gender"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "organization_id"
    t.bigint "role_id"
    t.string "mail"
    t.text "alias"
    t.bigint "detention_id"
    t.index ["detention_id"], name: "index_members_on_detention_id"
    t.index ["organization_id"], name: "index_members_on_organization_id"
    t.index ["role_id"], name: "index_members_on_role_id"
  end

  create_table "months", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "quarter_id", null: false
    t.datetime "first_day"
    t.index ["quarter_id"], name: "index_months_on_quarter_id"
  end

  create_table "organization_towns", force: :cascade do |t|
    t.bigint "town_id"
    t.bigint "organization_id"
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
    t.bigint "county_id"
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
    t.index ["county_id"], name: "index_organizations_on_county_id"
  end

  create_table "organizations_towns", force: :cascade do |t|
    t.bigint "town_id"
    t.bigint "organization_id"
    t.index ["organization_id"], name: "index_organizations_towns_on_organization_id"
    t.index ["town_id"], name: "index_organizations_towns_on_town_id"
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
    t.bigint "account_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["account_id"], name: "index_posts_on_account_id"
  end

  create_table "quarters", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "year_id"
    t.datetime "first_day"
    t.index ["year_id"], name: "index_quarters_on_year_id"
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
    t.bigint "member_id"
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

  create_table "towns", force: :cascade do |t|
    t.string "code"
    t.string "full_code"
    t.string "name"
    t.bigint "county_id", null: false
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
    t.bigint "town_id"
    t.bigint "organization_id"
    t.index ["organization_id"], name: "index_towns_and_organizations_on_organization_id"
    t.index ["town_id"], name: "index_towns_and_organizations_on_town_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "mail"
    t.string "mobile_phone"
    t.string "other_phone"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "member_id"
    t.string "password_digest"
    t.string "recovery_password_digest"
    t.integer "query_counter"
    t.string "remember_token"
    t.datetime "email_verified_at"
    t.integer "role_id", default: 2
    t.integer "membership_id"
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
    t.index ["member_id"], name: "index_users_on_member_id"
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
    t.bigint "killing_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "role_id"
    t.bigint "organization_id"
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
  add_foreign_key "keys", "users"
  add_foreign_key "killings", "events"
  add_foreign_key "leads", "events"
  add_foreign_key "members", "detentions"
  add_foreign_key "members", "organizations"
  add_foreign_key "members", "roles"
  add_foreign_key "months", "quarters"
  add_foreign_key "organizations", "counties"
  add_foreign_key "organizations", "leagues", column: "mainleague_id"
  add_foreign_key "organizations", "leagues", column: "subleague_id"
  add_foreign_key "organizations", "organizations", column: "parent_id"
  add_foreign_key "posts", "accounts"
  add_foreign_key "quarters", "years"
  add_foreign_key "sources", "members"
  add_foreign_key "states", "counties", column: "capital_id"
  add_foreign_key "towns", "counties"
  add_foreign_key "users", "members"
  add_foreign_key "victims", "killings"
  add_foreign_key "victims", "organizations"
  add_foreign_key "victims", "roles"
end
