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

ActiveRecord::Schema[8.1].define(version: 2026_04_24_120000) do
  create_table "activity_tracks", charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "duration_minutes"
    t.datetime "end_time"
    t.text "session_data", size: :long, collation: "utf8mb4_bin"
    t.datetime "start_time"
    t.string "title"
    t.bigint "total_focus_ms"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_activity_tracks_on_user_id"
    t.check_constraint "json_valid(`session_data`)", name: "session_data"
  end

  create_table "distractions", charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.string "category"
    t.datetime "created_at", null: false
    t.bigint "focus_session_id", null: false
    t.datetime "occurred_at"
    t.datetime "updated_at", null: false
    t.index ["focus_session_id"], name: "index_distractions_on_focus_session_id"
  end

  create_table "events", charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event_type"
    t.text "metadata", size: :long, collation: "utf8mb4_bin"
    t.bigint "session_id", null: false
    t.datetime "timestamp"
    t.datetime "updated_at", null: false
    t.index ["session_id"], name: "index_events_on_session_id"
    t.check_constraint "json_valid(`metadata`)", name: "metadata"
  end

  create_table "focus_sessions", charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.float "deep_work_score"
    t.integer "duration_minutes"
    t.bigint "elapsed_break_ms", default: 0, null: false
    t.bigint "elapsed_focus_ms", default: 0, null: false
    t.datetime "ended_at"
    t.integer "energy_level"
    t.datetime "last_synced_at"
    t.integer "planned_duration_minutes"
    t.text "session_data"
    t.datetime "started_at"
    t.string "status", default: "draft", null: false
    t.string "subject"
    t.string "topic"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["status"], name: "index_focus_sessions_on_status"
    t.index ["user_id"], name: "index_focus_sessions_on_user_id"
  end

  create_table "notes", charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.bigint "focus_session_id"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["deleted_at"], name: "index_notes_on_deleted_at"
    t.index ["focus_session_id"], name: "index_notes_on_focus_session_id"
    t.index ["user_id"], name: "index_notes_on_user_id"
  end

  create_table "reflections", charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date"
    t.text "improvements"
    t.text "main_distractions"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.text "what_went_well"
    t.index ["user_id"], name: "index_reflections_on_user_id"
  end

  create_table "sessions", charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "end_time"
    t.datetime "start_time"
    t.string "title"
    t.integer "total_away_ms"
    t.integer "total_focus_ms"
    t.datetime "updated_at", null: false
  end

  create_table "users", charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name"
    t.string "password_digest"
    t.datetime "updated_at", null: false
  end

  add_foreign_key "activity_tracks", "users"
  add_foreign_key "distractions", "focus_sessions"
  add_foreign_key "events", "sessions"
  add_foreign_key "focus_sessions", "users"
  add_foreign_key "notes", "focus_sessions"
  add_foreign_key "notes", "users"
  add_foreign_key "reflections", "users"
end
