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

ActiveRecord::Schema[8.1].define(version: 2026_03_09_030908) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "ahoy_events", force: :cascade do |t|
    t.string "name"
    t.text "properties"
    t.datetime "time"
    t.integer "user_id"
    t.integer "visit_id"
    t.index ["name", "time"], name: "index_ahoy_events_on_name_and_time"
    t.index ["user_id"], name: "index_ahoy_events_on_user_id"
    t.index ["visit_id"], name: "index_ahoy_events_on_visit_id"
  end

  create_table "ahoy_visits", force: :cascade do |t|
    t.string "app_version"
    t.string "browser"
    t.string "city"
    t.string "country"
    t.string "device_type"
    t.string "ip"
    t.text "landing_page"
    t.float "latitude"
    t.float "longitude"
    t.string "os"
    t.string "os_version"
    t.string "platform"
    t.text "referrer"
    t.string "referring_domain"
    t.string "region"
    t.datetime "started_at"
    t.text "user_agent"
    t.integer "user_id"
    t.string "utm_campaign"
    t.string "utm_content"
    t.string "utm_medium"
    t.string "utm_source"
    t.string "utm_term"
    t.string "visit_token"
    t.string "visitor_token"
    t.index ["user_id"], name: "index_ahoy_visits_on_user_id"
    t.index ["visit_token"], name: "index_ahoy_visits_on_visit_token", unique: true
    t.index ["visitor_token", "started_at"], name: "index_ahoy_visits_on_visitor_token_and_started_at"
  end

  create_table "albums", force: :cascade do |t|
    t.integer "artist_id", null: false
    t.datetime "created_at", null: false
    t.string "genre"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "year"
    t.string "youtube_playlist_url"
    t.index ["artist_id", "title"], name: "index_albums_on_artist_id_and_title", unique: true
    t.index ["artist_id"], name: "index_albums_on_artist_id"
  end

  create_table "api_keys", force: :cascade do |t|
    t.string "client_id", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.datetime "last_used_at"
    t.string "last_used_ip"
    t.string "name", null: false
    t.string "secret_key_digest", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["client_id"], name: "index_api_keys_on_client_id", unique: true
    t.index ["user_id"], name: "index_api_keys_on_user_id"
  end

  create_table "artists", force: :cascade do |t|
    t.string "category", default: "music", null: false
    t.datetime "created_at", null: false
    t.string "image_url"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_artists_on_category"
    t.index ["name"], name: "index_artists_on_name", unique: true
  end

  create_table "chats", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "model_id"
    t.datetime "updated_at", null: false
    t.index ["model_id"], name: "index_chats_on_model_id"
  end

  create_table "downloads", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "downloadable_id"
    t.string "downloadable_type", null: false
    t.string "error_message"
    t.integer "processed_tracks", default: 0
    t.string "status", default: "pending", null: false
    t.integer "total_tracks", default: 0
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "downloadable_type", "downloadable_id"], name: "idx_on_user_id_downloadable_type_downloadable_id_5f957f527c"
    t.index ["user_id"], name: "index_downloads_on_user_id"
  end

  create_table "epg_programmes", force: :cascade do |t|
    t.string "channel_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "ends_at", null: false
    t.datetime "starts_at", null: false
    t.string "subtitle"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["channel_id", "starts_at"], name: "index_epg_programmes_on_channel_id_and_starts_at"
    t.index ["ends_at"], name: "index_epg_programmes_on_ends_at"
  end

  create_table "favorites", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "favorable_id", null: false
    t.string "favorable_type", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "favorable_type", "favorable_id"], name: "index_favorites_on_user_id_and_favorable_type_and_favorable_id", unique: true
    t.index ["user_id"], name: "index_favorites_on_user_id"
  end

  create_table "flipper_features", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_flipper_features_on_key", unique: true
  end

  create_table "flipper_gates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "feature_key", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["feature_key", "key", "value"], name: "index_flipper_gates_on_feature_key_and_key_and_value", unique: true
  end

  create_table "internet_radio_categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.integer "stations_count", default: 0
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_internet_radio_categories_on_name", unique: true
    t.index ["slug"], name: "index_internet_radio_categories_on_slug", unique: true
  end

  create_table "internet_radio_stations", force: :cascade do |t|
    t.boolean "active", default: true
    t.integer "bitrate"
    t.string "codec"
    t.string "country"
    t.string "country_code"
    t.datetime "created_at", null: false
    t.string "favicon_url"
    t.string "homepage_url"
    t.integer "internet_radio_category_id"
    t.string "language"
    t.string "name", null: false
    t.string "stream_url", null: false
    t.string "tags"
    t.datetime "updated_at", null: false
    t.string "uuid"
    t.integer "votes", default: 0
    t.index ["active"], name: "index_internet_radio_stations_on_active"
    t.index ["country_code"], name: "index_internet_radio_stations_on_country_code"
    t.index ["internet_radio_category_id"], name: "index_internet_radio_stations_on_internet_radio_category_id"
    t.index ["uuid"], name: "index_internet_radio_stations_on_uuid", unique: true
  end

  create_table "iptv_categories", force: :cascade do |t|
    t.integer "channels_count", default: 0
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_iptv_categories_on_name", unique: true
    t.index ["slug"], name: "index_iptv_categories_on_slug", unique: true
  end

  create_table "iptv_channels", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "country"
    t.datetime "created_at", null: false
    t.integer "iptv_category_id"
    t.string "language"
    t.string "logo_url"
    t.string "name", null: false
    t.string "stream_url", null: false
    t.string "tvg_id"
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_iptv_channels_on_active"
    t.index ["country"], name: "index_iptv_channels_on_country"
    t.index ["iptv_category_id"], name: "index_iptv_channels_on_iptv_category_id"
    t.index ["name"], name: "index_iptv_channels_on_name"
    t.index ["tvg_id"], name: "index_iptv_channels_on_tvg_id", unique: true
  end

  create_table "maintenance_tasks_runs", force: :cascade do |t|
    t.text "arguments"
    t.text "backtrace"
    t.datetime "created_at", null: false
    t.string "cursor"
    t.datetime "ended_at"
    t.string "error_class"
    t.string "error_message"
    t.string "job_id"
    t.integer "lock_version", default: 0, null: false
    t.text "metadata"
    t.datetime "started_at"
    t.string "status", default: "enqueued", null: false
    t.string "task_name", null: false
    t.bigint "tick_count"
    t.bigint "tick_total"
    t.float "time_running", default: 0.0, null: false
    t.datetime "updated_at", null: false
    t.index ["task_name", "status", "created_at"], name: "index_maintenance_tasks_runs", order: { created_at: :desc }
  end

  create_table "messages", force: :cascade do |t|
    t.integer "cache_creation_tokens"
    t.integer "cached_tokens"
    t.integer "chat_id", null: false
    t.text "content"
    t.json "content_raw"
    t.datetime "created_at", null: false
    t.integer "input_tokens"
    t.integer "model_id"
    t.integer "output_tokens"
    t.string "role", null: false
    t.text "thinking_signature"
    t.text "thinking_text"
    t.integer "thinking_tokens"
    t.integer "tool_call_id"
    t.datetime "updated_at", null: false
    t.index ["chat_id"], name: "index_messages_on_chat_id"
    t.index ["model_id"], name: "index_messages_on_model_id"
    t.index ["role"], name: "index_messages_on_role"
    t.index ["tool_call_id"], name: "index_messages_on_tool_call_id"
  end

  create_table "models", force: :cascade do |t|
    t.json "capabilities", default: []
    t.integer "context_window"
    t.datetime "created_at", null: false
    t.string "family"
    t.date "knowledge_cutoff"
    t.integer "max_output_tokens"
    t.json "metadata", default: {}
    t.json "modalities", default: {}
    t.datetime "model_created_at"
    t.string "model_id", null: false
    t.string "name", null: false
    t.json "pricing", default: {}
    t.string "provider", null: false
    t.datetime "updated_at", null: false
    t.index ["family"], name: "index_models_on_family"
    t.index ["provider", "model_id"], name: "index_models_on_provider_and_model_id", unique: true
    t.index ["provider"], name: "index_models_on_provider"
  end

  create_table "play_histories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "played_at", null: false
    t.integer "track_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["track_id"], name: "index_play_histories_on_track_id"
    t.index ["user_id", "played_at"], name: "index_play_histories_on_user_id_and_played_at"
    t.index ["user_id"], name: "index_play_histories_on_user_id"
  end

  create_table "playlist_tracks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "playlist_id", null: false
    t.integer "position", null: false
    t.integer "track_id", null: false
    t.datetime "updated_at", null: false
    t.index ["playlist_id", "position"], name: "index_playlist_tracks_on_playlist_id_and_position", unique: true
    t.index ["playlist_id"], name: "index_playlist_tracks_on_playlist_id"
    t.index ["track_id"], name: "index_playlist_tracks_on_track_id"
  end

  create_table "playlists", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "playlist_tracks_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_playlists_on_user_id"
  end

  create_table "radio_stations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.string "original_url"
    t.string "source_type", default: "youtube", null: false
    t.string "stream_url"
    t.string "thumbnail_url"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.string "youtube_url"
    t.string "youtube_video_id"
    t.index ["user_id"], name: "index_radio_stations_on_user_id"
  end

  create_table "recordings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.float "duration"
    t.datetime "ends_at", null: false
    t.integer "epg_programme_id"
    t.string "error_message"
    t.integer "file_size"
    t.integer "iptv_channel_id", null: false
    t.datetime "starts_at", null: false
    t.string "status", default: "scheduled", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["epg_programme_id"], name: "index_recordings_on_epg_programme_id"
    t.index ["iptv_channel_id", "epg_programme_id"], name: "index_recordings_on_iptv_channel_id_and_epg_programme_id", unique: true, where: "status NOT IN ('failed', 'cancelled')"
    t.index ["iptv_channel_id"], name: "index_recordings_on_iptv_channel_id"
    t.index ["starts_at"], name: "index_recordings_on_starts_at"
    t.index ["status"], name: "index_recordings_on_status"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "tool_calls", force: :cascade do |t|
    t.json "arguments", default: {}
    t.datetime "created_at", null: false
    t.integer "message_id", null: false
    t.string "name", null: false
    t.string "thought_signature"
    t.string "tool_call_id", null: false
    t.datetime "updated_at", null: false
    t.index ["message_id"], name: "index_tool_calls_on_message_id"
    t.index ["name"], name: "index_tool_calls_on_name"
    t.index ["tool_call_id"], name: "index_tool_calls_on_tool_call_id", unique: true
  end

  create_table "tracks", force: :cascade do |t|
    t.integer "album_id", null: false
    t.integer "artist_id", null: false
    t.integer "bitrate"
    t.datetime "created_at", null: false
    t.integer "disc_number", default: 1
    t.float "duration"
    t.string "file_format"
    t.integer "file_size"
    t.string "title", null: false
    t.integer "track_number"
    t.datetime "updated_at", null: false
    t.string "youtube_video_id"
    t.index ["album_id", "disc_number", "track_number"], name: "index_tracks_on_album_id_and_disc_number_and_track_number"
    t.index ["album_id"], name: "index_tracks_on_album_id"
    t.index ["artist_id"], name: "index_tracks_on_artist_id"
    t.index ["youtube_video_id"], name: "index_tracks_on_youtube_video_id"
  end

  create_table "user_recordings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "recording_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["recording_id"], name: "index_user_recordings_on_recording_id"
    t.index ["user_id", "recording_id"], name: "index_user_recordings_on_user_id_and_recording_id", unique: true
    t.index ["user_id"], name: "index_user_recordings_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "name"
    t.string "password_digest", null: false
    t.string "subsonic_password"
    t.string "theme", default: "synthwave", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "albums", "artists"
  add_foreign_key "api_keys", "users"
  add_foreign_key "chats", "models"
  add_foreign_key "downloads", "users"
  add_foreign_key "favorites", "users"
  add_foreign_key "internet_radio_stations", "internet_radio_categories"
  add_foreign_key "iptv_channels", "iptv_categories"
  add_foreign_key "messages", "chats"
  add_foreign_key "messages", "models"
  add_foreign_key "messages", "tool_calls"
  add_foreign_key "play_histories", "tracks"
  add_foreign_key "play_histories", "users"
  add_foreign_key "playlist_tracks", "playlists"
  add_foreign_key "playlist_tracks", "tracks"
  add_foreign_key "playlists", "users"
  add_foreign_key "radio_stations", "users"
  add_foreign_key "recordings", "epg_programmes"
  add_foreign_key "recordings", "iptv_channels"
  add_foreign_key "sessions", "users"
  add_foreign_key "tool_calls", "messages"
  add_foreign_key "tracks", "albums"
  add_foreign_key "tracks", "artists"
  add_foreign_key "user_recordings", "recordings"
  add_foreign_key "user_recordings", "users"
end
