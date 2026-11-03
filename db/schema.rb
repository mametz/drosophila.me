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

ActiveRecord::Schema[8.1].define(version: 2026_11_03_200000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "crosses", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "male_fly_id"
    t.bigint "female_fly_id"
    t.bigint "parent_id"
    t.string "slug", null: false
    t.text "description"
    t.text "balancers", default: "", null: false
    t.text "lethal", default: "", null: false
    t.date "crossdate", null: false
    t.boolean "shared", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["female_fly_id"], name: "index_crosses_on_female_fly_id"
    t.index ["male_fly_id"], name: "index_crosses_on_male_fly_id"
    t.index ["parent_id"], name: "index_crosses_on_parent_id"
    t.index ["slug"], name: "index_crosses_on_slug", unique: true
    t.index ["user_id"], name: "index_crosses_on_user_id"
  end

  create_table "flies", force: :cascade do |t|
    t.text "chr1", null: false
    t.text "chr2", null: false
    t.text "chr3", null: false
    t.text "chr4", null: false
    t.bigint "cross_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cross_id"], name: "index_flies_on_cross_id"
  end

  create_table "rooms", force: :cascade do |t|
    t.string "name", null: false
    t.integer "temperature"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_rooms_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "stocks", force: :cascade do |t|
    t.integer "number"
    t.string "name"
    t.bigint "fly_id", null: false
    t.bigint "user_id", null: false
    t.bigint "room_id"
    t.text "comment"
    t.date "date_established"
    t.text "reference"
    t.text "received_from"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["fly_id"], name: "index_stocks_on_fly_id"
    t.index ["room_id"], name: "index_stocks_on_room_id"
    t.index ["user_id"], name: "index_stocks_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "crosses", "crosses", column: "parent_id", on_delete: :nullify
  add_foreign_key "crosses", "flies", column: "female_fly_id"
  add_foreign_key "crosses", "flies", column: "male_fly_id"
  add_foreign_key "crosses", "users"
  add_foreign_key "flies", "crosses", on_delete: :nullify
  add_foreign_key "rooms", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "stocks", "flies"
  add_foreign_key "stocks", "rooms", on_delete: :nullify
  add_foreign_key "stocks", "users"
end
