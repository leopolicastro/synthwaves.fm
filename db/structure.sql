CREATE TABLE IF NOT EXISTS "schema_migrations" ("version" varchar NOT NULL PRIMARY KEY);
CREATE TABLE IF NOT EXISTS "ar_internal_metadata" ("key" varchar NOT NULL PRIMARY KEY, "value" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE TABLE IF NOT EXISTS "users" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "email_address" varchar NOT NULL, "password_digest" varchar NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "admin" boolean DEFAULT FALSE NOT NULL /*application='GroovyTunes'*/, "name" varchar /*application='GroovyTunes'*/, "subsonic_password" varchar /*application='GroovyTunes'*/, "theme" varchar DEFAULT 'synthwave' NOT NULL /*application='SynthwavesFm'*/, "youtube_api_key" varchar /*application='SynthWaves'*/);
CREATE UNIQUE INDEX "index_users_on_email_address" ON "users" ("email_address") /*application='GroovyTunes'*/;
CREATE TABLE IF NOT EXISTS "sessions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "user_id" integer NOT NULL, "ip_address" varchar, "user_agent" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_758836b4f0"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_sessions_on_user_id" ON "sessions" ("user_id") /*application='GroovyTunes'*/;
CREATE TABLE IF NOT EXISTS "api_keys" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "user_id" integer NOT NULL, "name" varchar NOT NULL, "client_id" varchar NOT NULL, "secret_key_digest" varchar NOT NULL, "expires_at" datetime(6), "last_used_at" datetime(6), "last_used_ip" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_32c28d0dc2"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_api_keys_on_user_id" ON "api_keys" ("user_id") /*application='GroovyTunes'*/;
CREATE UNIQUE INDEX "index_api_keys_on_client_id" ON "api_keys" ("client_id") /*application='GroovyTunes'*/;
CREATE TABLE IF NOT EXISTS "maintenance_tasks_runs" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "task_name" varchar NOT NULL, "started_at" datetime(6), "ended_at" datetime(6), "time_running" float DEFAULT 0.0 NOT NULL, "tick_count" bigint, "tick_total" bigint, "job_id" varchar, "cursor" varchar, "status" varchar DEFAULT 'enqueued' NOT NULL, "error_class" varchar, "error_message" varchar, "backtrace" text, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "arguments" text, "lock_version" integer DEFAULT 0 NOT NULL, "metadata" text /*application='GroovyTunes'*/);
CREATE INDEX "index_maintenance_tasks_runs" ON "maintenance_tasks_runs" ("task_name", "status", "created_at" DESC) /*application='GroovyTunes'*/;
CREATE TABLE IF NOT EXISTS "flipper_features" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "key" varchar NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_flipper_features_on_key" ON "flipper_features" ("key") /*application='GroovyTunes'*/;
CREATE TABLE IF NOT EXISTS "flipper_gates" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "feature_key" varchar NOT NULL, "key" varchar NOT NULL, "value" text, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_flipper_gates_on_feature_key_and_key_and_value" ON "flipper_gates" ("feature_key", "key", "value") /*application='GroovyTunes'*/;
CREATE TABLE IF NOT EXISTS "active_storage_blobs" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "key" varchar NOT NULL, "filename" varchar NOT NULL, "content_type" varchar, "metadata" text, "service_name" varchar NOT NULL, "byte_size" bigint NOT NULL, "checksum" varchar, "created_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_active_storage_blobs_on_key" ON "active_storage_blobs" ("key") /*application='GroovyTunes'*/;
CREATE TABLE IF NOT EXISTS "active_storage_attachments" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar NOT NULL, "record_type" varchar NOT NULL, "record_id" bigint NOT NULL, "blob_id" bigint NOT NULL, "created_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_c3b3935057"
FOREIGN KEY ("blob_id")
  REFERENCES "active_storage_blobs" ("id")
);
CREATE INDEX "index_active_storage_attachments_on_blob_id" ON "active_storage_attachments" ("blob_id") /*application='GroovyTunes'*/;
CREATE UNIQUE INDEX "index_active_storage_attachments_uniqueness" ON "active_storage_attachments" ("record_type", "record_id", "name", "blob_id") /*application='GroovyTunes'*/;
CREATE TABLE IF NOT EXISTS "active_storage_variant_records" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "blob_id" bigint NOT NULL, "variation_digest" varchar NOT NULL, CONSTRAINT "fk_rails_993965df05"
FOREIGN KEY ("blob_id")
  REFERENCES "active_storage_blobs" ("id")
);
CREATE UNIQUE INDEX "index_active_storage_variant_records_uniqueness" ON "active_storage_variant_records" ("blob_id", "variation_digest") /*application='GroovyTunes'*/;
CREATE TABLE IF NOT EXISTS "models" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "model_id" varchar NOT NULL, "name" varchar NOT NULL, "provider" varchar NOT NULL, "family" varchar, "model_created_at" datetime(6), "context_window" integer, "max_output_tokens" integer, "knowledge_cutoff" date, "modalities" json DEFAULT '{}', "capabilities" json DEFAULT '[]', "pricing" json DEFAULT '{}', "metadata" json DEFAULT '{}', "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_models_on_provider_and_model_id" ON "models" ("provider", "model_id") /*application='GroovyTunes'*/;
CREATE INDEX "index_models_on_provider" ON "models" ("provider") /*application='GroovyTunes'*/;
CREATE INDEX "index_models_on_family" ON "models" ("family") /*application='GroovyTunes'*/;
CREATE TABLE IF NOT EXISTS "chats" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "model_id" integer, CONSTRAINT "fk_rails_1835d93df1"
FOREIGN KEY ("model_id")
  REFERENCES "models" ("id")
);
CREATE INDEX "index_chats_on_model_id" ON "chats" ("model_id") /*application='GroovyTunes'*/;
CREATE TABLE IF NOT EXISTS "tool_calls" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "tool_call_id" varchar NOT NULL, "name" varchar NOT NULL, "thought_signature" varchar, "arguments" json DEFAULT '{}', "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "message_id" integer NOT NULL, CONSTRAINT "fk_rails_9c8daee481"
FOREIGN KEY ("message_id")
  REFERENCES "messages" ("id")
);
CREATE UNIQUE INDEX "index_tool_calls_on_tool_call_id" ON "tool_calls" ("tool_call_id") /*application='GroovyTunes'*/;
CREATE INDEX "index_tool_calls_on_name" ON "tool_calls" ("name") /*application='GroovyTunes'*/;
CREATE INDEX "index_tool_calls_on_message_id" ON "tool_calls" ("message_id") /*application='GroovyTunes'*/;
CREATE TABLE IF NOT EXISTS "messages" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "role" varchar NOT NULL, "content" text, "content_raw" json, "thinking_text" text, "thinking_signature" text, "thinking_tokens" integer, "input_tokens" integer, "output_tokens" integer, "cached_tokens" integer, "cache_creation_tokens" integer, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "chat_id" integer NOT NULL, "model_id" integer, "tool_call_id" integer, CONSTRAINT "fk_rails_c02b47ad97"
FOREIGN KEY ("model_id")
  REFERENCES "models" ("id")
, CONSTRAINT "fk_rails_0f670de7ba"
FOREIGN KEY ("chat_id")
  REFERENCES "chats" ("id")
, CONSTRAINT "fk_rails_552873cb52"
FOREIGN KEY ("tool_call_id")
  REFERENCES "tool_calls" ("id")
);
CREATE INDEX "index_messages_on_role" ON "messages" ("role") /*application='GroovyTunes'*/;
CREATE INDEX "index_messages_on_chat_id" ON "messages" ("chat_id") /*application='GroovyTunes'*/;
CREATE INDEX "index_messages_on_model_id" ON "messages" ("model_id") /*application='GroovyTunes'*/;
CREATE INDEX "index_messages_on_tool_call_id" ON "messages" ("tool_call_id") /*application='GroovyTunes'*/;
CREATE TABLE IF NOT EXISTS "ahoy_visits" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "visit_token" varchar, "visitor_token" varchar, "user_id" integer, "ip" varchar, "user_agent" text, "referrer" text, "referring_domain" varchar, "landing_page" text, "browser" varchar, "os" varchar, "device_type" varchar, "country" varchar, "region" varchar, "city" varchar, "latitude" float, "longitude" float, "utm_source" varchar, "utm_medium" varchar, "utm_term" varchar, "utm_content" varchar, "utm_campaign" varchar, "app_version" varchar, "os_version" varchar, "platform" varchar, "started_at" datetime(6));
CREATE INDEX "index_ahoy_visits_on_user_id" ON "ahoy_visits" ("user_id") /*application='GroovyTunes'*/;
CREATE UNIQUE INDEX "index_ahoy_visits_on_visit_token" ON "ahoy_visits" ("visit_token") /*application='GroovyTunes'*/;
CREATE INDEX "index_ahoy_visits_on_visitor_token_and_started_at" ON "ahoy_visits" ("visitor_token", "started_at") /*application='GroovyTunes'*/;
CREATE TABLE IF NOT EXISTS "ahoy_events" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "visit_id" integer, "user_id" integer, "name" varchar, "properties" text, "time" datetime(6));
CREATE INDEX "index_ahoy_events_on_visit_id" ON "ahoy_events" ("visit_id") /*application='GroovyTunes'*/;
CREATE INDEX "index_ahoy_events_on_user_id" ON "ahoy_events" ("user_id") /*application='GroovyTunes'*/;
CREATE INDEX "index_ahoy_events_on_name_and_time" ON "ahoy_events" ("name", "time") /*application='GroovyTunes'*/;
CREATE TABLE IF NOT EXISTS "playlists" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar NOT NULL, "user_id" integer NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "playlist_tracks_count" integer DEFAULT 0 NOT NULL /*application='SynthwavesFm'*/, CONSTRAINT "fk_rails_d67ef1eb45"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_playlists_on_user_id" ON "playlists" ("user_id") /*application='GroovyTunes'*/;
CREATE TABLE IF NOT EXISTS "playlist_tracks" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "playlist_id" integer NOT NULL, "track_id" integer NOT NULL, "position" integer NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_2ea000150b"
FOREIGN KEY ("playlist_id")
  REFERENCES "playlists" ("id")
, CONSTRAINT "fk_rails_6de46fb8a2"
FOREIGN KEY ("track_id")
  REFERENCES "tracks" ("id")
);
CREATE INDEX "index_playlist_tracks_on_playlist_id" ON "playlist_tracks" ("playlist_id") /*application='GroovyTunes'*/;
CREATE INDEX "index_playlist_tracks_on_track_id" ON "playlist_tracks" ("track_id") /*application='GroovyTunes'*/;
CREATE UNIQUE INDEX "index_playlist_tracks_on_playlist_id_and_position" ON "playlist_tracks" ("playlist_id", "position") /*application='GroovyTunes'*/;
CREATE TABLE IF NOT EXISTS "favorites" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "user_id" integer NOT NULL, "favorable_type" varchar NOT NULL, "favorable_id" integer NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_d15744e438"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_favorites_on_user_id" ON "favorites" ("user_id") /*application='GroovyTunes'*/;
CREATE UNIQUE INDEX "index_favorites_on_user_id_and_favorable_type_and_favorable_id" ON "favorites" ("user_id", "favorable_type", "favorable_id") /*application='GroovyTunes'*/;
CREATE TABLE IF NOT EXISTS "play_histories" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "user_id" integer NOT NULL, "track_id" integer NOT NULL, "played_at" datetime(6) NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_325b78ed95"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
, CONSTRAINT "fk_rails_f38895a0c7"
FOREIGN KEY ("track_id")
  REFERENCES "tracks" ("id")
);
CREATE INDEX "index_play_histories_on_user_id" ON "play_histories" ("user_id") /*application='GroovyTunes'*/;
CREATE INDEX "index_play_histories_on_track_id" ON "play_histories" ("track_id") /*application='GroovyTunes'*/;
CREATE INDEX "index_play_histories_on_user_id_and_played_at" ON "play_histories" ("user_id", "played_at") /*application='GroovyTunes'*/;
CREATE TABLE IF NOT EXISTS "external_streams" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "user_id" integer NOT NULL, "name" varchar NOT NULL, "youtube_url" varchar, "youtube_video_id" varchar, "thumbnail_url" varchar, "description" text, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "source_type" varchar DEFAULT 'youtube' NOT NULL, "stream_url" varchar, "original_url" varchar, CONSTRAINT "fk_rails_0b9af78719"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
);
CREATE TABLE IF NOT EXISTS "downloads" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "user_id" integer NOT NULL, "downloadable_type" varchar NOT NULL, "downloadable_id" integer, "status" varchar DEFAULT 'pending' NOT NULL, "total_tracks" integer DEFAULT 0, "processed_tracks" integer DEFAULT 0, "error_message" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_0cd58e10e1"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_downloads_on_user_id" ON "downloads" ("user_id") /*application='SynthWavesFm'*/;
CREATE INDEX "idx_on_user_id_downloadable_type_downloadable_id_5f957f527c" ON "downloads" ("user_id", "downloadable_type", "downloadable_id") /*application='SynthWavesFm'*/;
CREATE TABLE IF NOT EXISTS "iptv_categories" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar NOT NULL, "slug" varchar NOT NULL, "channels_count" integer DEFAULT 0, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_iptv_categories_on_name" ON "iptv_categories" ("name") /*application='SynthWaves'*/;
CREATE UNIQUE INDEX "index_iptv_categories_on_slug" ON "iptv_categories" ("slug") /*application='SynthWaves'*/;
CREATE TABLE IF NOT EXISTS "iptv_channels" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar NOT NULL, "tvg_id" varchar, "stream_url" varchar NOT NULL, "logo_url" varchar, "country" varchar, "language" varchar, "iptv_category_id" integer, "active" boolean DEFAULT TRUE NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "epg_url" varchar /*application='SynthWaves'*/, CONSTRAINT "fk_rails_d8bbb12557"
FOREIGN KEY ("iptv_category_id")
  REFERENCES "iptv_categories" ("id")
);
CREATE INDEX "index_iptv_channels_on_iptv_category_id" ON "iptv_channels" ("iptv_category_id") /*application='SynthWaves'*/;
CREATE UNIQUE INDEX "index_iptv_channels_on_tvg_id" ON "iptv_channels" ("tvg_id") /*application='SynthWaves'*/;
CREATE INDEX "index_iptv_channels_on_name" ON "iptv_channels" ("name") /*application='SynthWaves'*/;
CREATE INDEX "index_iptv_channels_on_country" ON "iptv_channels" ("country") /*application='SynthWaves'*/;
CREATE INDEX "index_iptv_channels_on_active" ON "iptv_channels" ("active") /*application='SynthWaves'*/;
CREATE TABLE IF NOT EXISTS "epg_programmes" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "channel_id" varchar NOT NULL, "title" varchar NOT NULL, "subtitle" varchar, "description" text, "starts_at" datetime(6) NOT NULL, "ends_at" datetime(6) NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE INDEX "index_epg_programmes_on_ends_at" ON "epg_programmes" ("ends_at") /*application='SynthWaves'*/;
CREATE TABLE IF NOT EXISTS "user_recordings" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "user_id" integer NOT NULL, "recording_id" integer NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_e0df93d08f"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
, CONSTRAINT "fk_rails_076b6fda66"
FOREIGN KEY ("recording_id")
  REFERENCES "recordings" ("id")
);
CREATE INDEX "index_user_recordings_on_user_id" ON "user_recordings" ("user_id") /*application='SynthWaves'*/;
CREATE INDEX "index_user_recordings_on_recording_id" ON "user_recordings" ("recording_id") /*application='SynthWaves'*/;
CREATE UNIQUE INDEX "index_user_recordings_on_user_id_and_recording_id" ON "user_recordings" ("user_id", "recording_id") /*application='SynthWaves'*/;
CREATE TABLE IF NOT EXISTS "internet_radio_categories" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar NOT NULL, "slug" varchar NOT NULL, "stations_count" integer DEFAULT 0, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_internet_radio_categories_on_name" ON "internet_radio_categories" ("name") /*application='SynthWaves'*/;
CREATE UNIQUE INDEX "index_internet_radio_categories_on_slug" ON "internet_radio_categories" ("slug") /*application='SynthWaves'*/;
CREATE TABLE IF NOT EXISTS "internet_radio_stations" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "uuid" varchar, "name" varchar NOT NULL, "stream_url" varchar NOT NULL, "homepage_url" varchar, "favicon_url" varchar, "country" varchar, "country_code" varchar, "language" varchar, "tags" varchar, "codec" varchar, "bitrate" integer, "votes" integer DEFAULT 0, "internet_radio_category_id" integer, "active" boolean DEFAULT TRUE, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_5454deec1d"
FOREIGN KEY ("internet_radio_category_id")
  REFERENCES "internet_radio_categories" ("id")
);
CREATE INDEX "index_internet_radio_stations_on_internet_radio_category_id" ON "internet_radio_stations" ("internet_radio_category_id") /*application='SynthWaves'*/;
CREATE UNIQUE INDEX "index_internet_radio_stations_on_uuid" ON "internet_radio_stations" ("uuid") /*application='SynthWaves'*/;
CREATE INDEX "index_internet_radio_stations_on_country_code" ON "internet_radio_stations" ("country_code") /*application='SynthWaves'*/;
CREATE INDEX "index_internet_radio_stations_on_active" ON "internet_radio_stations" ("active") /*application='SynthWaves'*/;
CREATE TABLE IF NOT EXISTS "recordings" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "iptv_channel_id" integer NOT NULL, "epg_programme_id" integer, "title" varchar NOT NULL, "starts_at" datetime(6) NOT NULL, "ends_at" datetime(6) NOT NULL, "status" varchar DEFAULT 'scheduled' NOT NULL, "error_message" varchar, "file_size" integer, "duration" float, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_e9afaa6b29"
FOREIGN KEY ("iptv_channel_id")
  REFERENCES "iptv_channels" ("id")
, CONSTRAINT "fk_rails_16ceab2a19"
FOREIGN KEY ("epg_programme_id")
  REFERENCES "epg_programmes" ("id")
 ON DELETE SET NULL);
CREATE INDEX "index_recordings_on_iptv_channel_id" ON "recordings" ("iptv_channel_id") /*application='SynthWaves'*/;
CREATE INDEX "index_recordings_on_epg_programme_id" ON "recordings" ("epg_programme_id") /*application='SynthWaves'*/;
CREATE INDEX "index_recordings_on_starts_at" ON "recordings" ("starts_at") /*application='SynthWaves'*/;
CREATE UNIQUE INDEX "index_recordings_on_iptv_channel_id_and_epg_programme_id" ON "recordings" ("iptv_channel_id", "epg_programme_id") WHERE status NOT IN ('failed', 'cancelled') /*application='SynthWaves'*/;
CREATE INDEX "index_recordings_on_status" ON "recordings" ("status") /*application='SynthWaves'*/;
CREATE TABLE IF NOT EXISTS "folders" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "user_id" integer NOT NULL, "name" varchar NOT NULL, "description" text, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_2a04d378cf"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_folders_on_user_id" ON "folders" ("user_id") /*application='SynthWaves'*/;
CREATE UNIQUE INDEX "index_folders_on_user_id_and_name" ON "folders" ("user_id", "name") /*application='SynthWaves'*/;
CREATE TABLE IF NOT EXISTS "videos" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "user_id" integer NOT NULL, "title" varchar NOT NULL, "description" text, "duration" float, "width" integer, "height" integer, "file_format" varchar, "file_size" bigint, "video_codec" varchar, "audio_codec" varchar, "bitrate" integer, "status" varchar DEFAULT 'processing' NOT NULL, "error_message" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "folder_id" integer, "season_number" integer /*application='SynthWaves'*/, "episode_number" integer /*application='SynthWaves'*/, "download_status" varchar /*application='SynthWaves'*/, "download_error" varchar /*application='SynthWaves'*/, "youtube_video_id" varchar /*application='SynthWaves'*/, "audio_channels" integer /*application='SynthWaves'*/, CONSTRAINT "fk_rails_ba925d1105"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
, CONSTRAINT "fk_rails_e1fd47dbfa"
FOREIGN KEY ("folder_id")
  REFERENCES "folders" ("id")
);
CREATE INDEX "index_videos_on_user_id" ON "videos" ("user_id") /*application='SynthWaves'*/;
CREATE INDEX "index_videos_on_folder_id" ON "videos" ("folder_id") /*application='SynthWaves'*/;
CREATE INDEX "index_videos_on_folder_id_and_season_number_and_episode_number" ON "videos" ("folder_id", "season_number", "episode_number") /*application='SynthWaves'*/;
CREATE UNIQUE INDEX "index_epg_programmes_on_channel_id_and_starts_at" ON "epg_programmes" ("channel_id", "starts_at") /*application='SynthWaves'*/;
CREATE TABLE IF NOT EXISTS "tags" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar NOT NULL, "tag_type" varchar NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_tags_on_name_and_tag_type" ON "tags" ("name", "tag_type") /*application='SynthWaves'*/;
CREATE TABLE IF NOT EXISTS "taggings" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "tag_id" integer NOT NULL, "taggable_type" varchar NOT NULL, "taggable_id" bigint NOT NULL, "user_id" integer NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_9fcd2e236b"
FOREIGN KEY ("tag_id")
  REFERENCES "tags" ("id")
, CONSTRAINT "fk_rails_6f324377bd"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_taggings_on_tag_id" ON "taggings" ("tag_id") /*application='SynthWaves'*/;
CREATE INDEX "index_taggings_on_user_id" ON "taggings" ("user_id") /*application='SynthWaves'*/;
CREATE UNIQUE INDEX "index_taggings_uniqueness" ON "taggings" ("tag_id", "taggable_type", "taggable_id", "user_id") /*application='SynthWaves'*/;
CREATE INDEX "index_taggings_on_taggable_type_and_taggable_id" ON "taggings" ("taggable_type", "taggable_id") /*application='SynthWaves'*/;
CREATE INDEX "index_videos_on_youtube_video_id" ON "videos" ("youtube_video_id") /*application='SynthWaves'*/;
CREATE VIRTUAL TABLE tracks_search USING fts5(
  track_title,
  artist_name,
  album_title,
  track_id UNINDEXED,
  tokenize='unicode61 remove_diacritics 2'
)
/* tracks_search(track_title,artist_name,album_title,track_id) */;
CREATE TABLE IF NOT EXISTS "artists" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar NOT NULL, "image_url" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "category" varchar DEFAULT 'music' NOT NULL, "user_id" integer NOT NULL, "apple_music_storefront" varchar /*application='SynthWaves'*/);
CREATE INDEX "index_artists_on_category" ON "artists" ("category") /*application='SynthWaves'*/;
CREATE TABLE IF NOT EXISTS "albums" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "title" varchar NOT NULL, "artist_id" integer NOT NULL, "year" integer, "genre" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "youtube_playlist_url" varchar, "user_id" integer NOT NULL, CONSTRAINT "fk_rails_124a79559a"
FOREIGN KEY ("artist_id")
  REFERENCES "artists" ("id")
);
CREATE INDEX "index_albums_on_artist_id" ON "albums" ("artist_id") /*application='SynthWaves'*/;
CREATE UNIQUE INDEX "index_albums_on_artist_id_and_title" ON "albums" ("artist_id", "title") /*application='SynthWaves'*/;
CREATE TABLE IF NOT EXISTS "tracks" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "title" varchar NOT NULL, "album_id" integer NOT NULL, "artist_id" integer NOT NULL, "track_number" integer, "disc_number" integer DEFAULT 1, "duration" float, "file_format" varchar, "file_size" integer, "bitrate" integer, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "youtube_video_id" varchar, "lyrics" text, "download_status" varchar, "download_error" varchar, "user_id" integer NOT NULL, "apple_music_id" varchar /*application='SynthWaves'*/, "isrc" varchar /*application='SynthWaves'*/, "content_rating" varchar /*application='SynthWaves'*/, "language" varchar /*application='SynthWaves'*/, "release_year" integer /*application='SynthWaves'*/, "enrichment_status" varchar /*application='SynthWaves'*/, "enriched_at" datetime(6) /*application='SynthWaves'*/, CONSTRAINT "fk_rails_d99a0cbd74"
FOREIGN KEY ("artist_id")
  REFERENCES "artists" ("id")
, CONSTRAINT "fk_rails_7c47d80164"
FOREIGN KEY ("album_id")
  REFERENCES "albums" ("id")
);
CREATE INDEX "index_tracks_on_album_id" ON "tracks" ("album_id") /*application='SynthWaves'*/;
CREATE INDEX "index_tracks_on_artist_id" ON "tracks" ("artist_id") /*application='SynthWaves'*/;
CREATE INDEX "index_tracks_on_album_id_and_disc_number_and_track_number" ON "tracks" ("album_id", "disc_number", "track_number") /*application='SynthWaves'*/;
CREATE INDEX "index_tracks_on_youtube_video_id" ON "tracks" ("youtube_video_id") /*application='SynthWaves'*/;
CREATE UNIQUE INDEX "index_artists_on_user_id_and_name" ON "artists" ("user_id", "name") /*application='SynthWaves'*/;
CREATE INDEX "index_albums_on_user_id" ON "albums" ("user_id") /*application='SynthWaves'*/;
CREATE INDEX "index_tracks_on_user_id" ON "tracks" ("user_id") /*application='SynthWaves'*/;
CREATE TABLE IF NOT EXISTS "video_playback_positions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "user_id" integer NOT NULL, "video_id" integer NOT NULL, "position" float DEFAULT 0.0 NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_362a9c6c93"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
, CONSTRAINT "fk_rails_37e283a0b8"
FOREIGN KEY ("video_id")
  REFERENCES "videos" ("id")
);
CREATE INDEX "index_video_playback_positions_on_user_id" ON "video_playback_positions" ("user_id") /*application='SynthWaves'*/;
CREATE INDEX "index_video_playback_positions_on_video_id" ON "video_playback_positions" ("video_id") /*application='SynthWaves'*/;
CREATE UNIQUE INDEX "index_video_playback_positions_on_user_id_and_video_id" ON "video_playback_positions" ("user_id", "video_id") /*application='SynthWaves'*/;
CREATE INDEX "index_external_streams_on_user_id" ON "external_streams" ("user_id") /*application='SynthWaves'*/;
CREATE TABLE IF NOT EXISTS "radio_stations" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "playlist_id" integer NOT NULL, "user_id" integer NOT NULL, "status" varchar DEFAULT 'stopped' NOT NULL, "mount_point" varchar NOT NULL, "playback_mode" varchar DEFAULT 'shuffle' NOT NULL, "bitrate" integer DEFAULT 192 NOT NULL, "crossfade" boolean DEFAULT TRUE NOT NULL, "crossfade_duration" float DEFAULT 3.0 NOT NULL, "current_track_id" integer, "listener_count" integer DEFAULT 0, "error_message" text, "started_at" datetime(6), "last_track_at" datetime(6), "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "queued_track_id" integer, CONSTRAINT "fk_rails_030bf29ea1"
FOREIGN KEY ("current_track_id")
  REFERENCES "tracks" ("id")
, CONSTRAINT "fk_rails_0b9af78719"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
, CONSTRAINT "fk_rails_a5b9b61969"
FOREIGN KEY ("playlist_id")
  REFERENCES "playlists" ("id")
, CONSTRAINT "fk_rails_7aec4f103b"
FOREIGN KEY ("queued_track_id")
  REFERENCES "tracks" ("id")
);
CREATE UNIQUE INDEX "index_radio_stations_on_playlist_id" ON "radio_stations" ("playlist_id") /*application='SynthWaves'*/;
CREATE INDEX "index_radio_stations_on_user_id" ON "radio_stations" ("user_id") /*application='SynthWaves'*/;
CREATE INDEX "index_radio_stations_on_current_track_id" ON "radio_stations" ("current_track_id") /*application='SynthWaves'*/;
CREATE UNIQUE INDEX "index_radio_stations_on_mount_point" ON "radio_stations" ("mount_point") /*application='SynthWaves'*/;
CREATE INDEX "index_radio_stations_on_status" ON "radio_stations" ("status") /*application='SynthWaves'*/;
CREATE INDEX "index_radio_stations_on_queued_track_id" ON "radio_stations" ("queued_track_id") /*application='SynthWaves'*/;
CREATE INDEX "index_tracks_on_apple_music_id" ON "tracks" ("apple_music_id") /*application='SynthWaves'*/;
CREATE INDEX "index_tracks_on_isrc" ON "tracks" ("isrc") /*application='SynthWaves'*/;
CREATE INDEX "index_tracks_on_language" ON "tracks" ("language") /*application='SynthWaves'*/;
CREATE INDEX "index_tracks_on_release_year" ON "tracks" ("release_year") /*application='SynthWaves'*/;
CREATE INDEX "index_tracks_on_enrichment_status" ON "tracks" ("enrichment_status") /*application='SynthWaves'*/;
INSERT INTO "schema_migrations" (version) VALUES
('20260329130613'),
('20260329130608'),
('20260328213859'),
('20260326235243'),
('20260326231506'),
('20260313152644'),
('20260312231556'),
('20260312124420'),
('20260311205713'),
('20260311202752'),
('20260310220019'),
('20260310220013'),
('20260310043429'),
('20260310043415'),
('20260310041427'),
('20260309194120'),
('20260309183145'),
('20260309183140'),
('20260309171759'),
('20260309150604'),
('20260309030908'),
('20260309030902'),
('20260309024111'),
('20260309023501'),
('20260309012756'),
('20260309000002'),
('20260309000001'),
('20260308231131'),
('20260308221632'),
('20260308215613'),
('20260308205211'),
('20260308183253'),
('20260308174202'),
('20260308162429'),
('20260308162416'),
('20260308150724'),
('20260308141330'),
('20260308023843'),
('20260308023243'),
('20260308023241'),
('20260308023240'),
('20260308023239'),
('20260308023227'),
('20260308023218'),
('20260308023211'),
('20260308005410'),
('20260308005406'),
('20260308005405'),
('20260308005404'),
('20260308005403'),
('20260308005402'),
('20260308005363'),
('20260308005362'),
('20260308005361'),
('20260308005360'),
('20260308005359'),
('20260308005358'),
('20260308005357'),
('20260308005356'),
('20260308005355'),
('20260308005354'),
('20260308005345'),
('20260308005342'),
('20260308005341'),
('20260308005340'),
('20260308005339'),
('0');

