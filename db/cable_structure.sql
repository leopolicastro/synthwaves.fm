CREATE TABLE IF NOT EXISTS "solid_cable_messages" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "channel" blob(1024) NOT NULL, "payload" blob(536870912) NOT NULL, "created_at" datetime(6) NOT NULL, "channel_hash" integer(8) NOT NULL);
CREATE INDEX "index_solid_cable_messages_on_channel" ON "solid_cable_messages" ("channel") /*application='GroovyTunes'*/;
CREATE INDEX "index_solid_cable_messages_on_channel_hash" ON "solid_cable_messages" ("channel_hash") /*application='GroovyTunes'*/;
CREATE INDEX "index_solid_cable_messages_on_created_at" ON "solid_cable_messages" ("created_at") /*application='GroovyTunes'*/;
CREATE TABLE IF NOT EXISTS "schema_migrations" ("version" varchar NOT NULL PRIMARY KEY);
CREATE TABLE IF NOT EXISTS "ar_internal_metadata" ("key" varchar NOT NULL PRIMARY KEY, "value" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
INSERT INTO "schema_migrations" (version) VALUES
('1');

