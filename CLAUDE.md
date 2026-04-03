# synthwaves.fm

Music streaming web application built with Rails 8.

## Common Commands

```bash
bin/dev                  # Start dev server (Rails + Tailwind watcher)
bin/rspec                # Run full test suite
bin/rspec spec/models/   # Run model specs only
bin/rails db:migrate     # Run migrations
bin/rails db:seed        # Seed database
bin/setup                # Install deps, prepare DB, start server
bundle exec standardrb   # Lint Ruby code
bundle exec brakeman     # Security scan
```

## Architecture

- **Rails 8.1** with Propshaft asset pipeline
- **Hotwire**: Turbo for navigation, Stimulus for interactivity
- **Importmap** for JavaScript (no bundler)
- **Tailwind CSS** via tailwindcss-rails
- **ViewComponent** for reusable UI components (app/components/)
- **SQLite** for all databases (primary, cache, queue, cable)
- **Solid Queue/Cache/Cable** for background jobs, caching, and WebSockets
- **Pagy** for pagination
- **Flipper** for the `:open_registration` feature flag (sole remaining flag)

### Key Gems

- **ruby_llm** - AI chat integration with streaming via ActionCable
- **wahwah** - Audio metadata extraction
- **ffmpeg** - Audio format conversion (handled by AudioConversionJob)
- **ahoy_matey** - Analytics/event tracking
- **madmin** - Admin panel at `/admin`

## Domain Models

```
Artist
  has_many :albums
  has_many :tracks
  validates name uniqueness

Album
  belongs_to :artist
  has_many :tracks (dependent: :destroy)
  has_one_attached :cover_image
  validates title uniqueness scoped to artist

Track
  belongs_to :album
  belongs_to :artist
  has_one_attached :audio_file
  has_many :playlist_tracks, :favorites, :play_histories

Playlist
  belongs_to :user
  has_many :playlist_tracks (ordered by position)
  has_many :tracks (through: :playlist_tracks)

PlaylistTrack  -- join table with position column

User
  include Themeable
  has_many :playlists, :favorites, :play_histories, :api_keys, :sessions
  has_secure_password
  theme (string, default: "synthwave") — validated against Themeable::THEMES

RadioStation
  belongs_to :playlist
  belongs_to :user
  belongs_to :current_track (optional)
  status: stopped|starting|active|idle|error
  mount_point, playback_mode, bitrate, crossfade settings

Favorite  -- polymorphic (favorable: Track | Album | Artist)
PlayHistory  -- records play events per user/track

APIKey
  belongs_to :user
  has_secure_password :secret_key
  client_id format: "bc_" + 32 hex chars

Session  -- tracks user_agent, ip_address
Current  -- ActiveSupport::CurrentAttributes holding current session/user
```

## Authentication

Three authentication layers:

1. **Web sessions** - Signed HTTP-only cookies via `Authentication` concern. Session records track user_agent and ip_address.

2. **JWT API** (`/api/v1/`) - Client authenticates with `client_id` + `secret_key` to `POST /api/v1/auth/token`. Returns HS256 JWT (1-hour expiry) using `JWTService`. API requests use `Authorization: Bearer <token>` header. Validated in `API::V1::BaseController`.

3. **Subsonic API** (`/rest/` and `/api/rest/`) - Username via `:u` param (email_address). Two auth methods: MD5 token (`:t` + `:s` salt) or plaintext password (`:p` param, optional hex encoding with `enc:` prefix). Uses `subsonic_password` field on User. Response format controlled by `:f` param (JSON or XML).

## Theming

Four music-genre-inspired themes: **Synthwave** (default), **Reggae**, **Punk**, **Jazz**. Themes swap CSS custom properties via `[data-theme]` selectors — no template changes needed.

### How It Works

- `Themeable` concern (`app/models/concerns/themeable.rb`) is the single source of truth for the theme registry (label, font, meta color per theme)
- `ThemeHelper` provides `current_theme` (`Current.user&.theme` or default), `current_theme_font_url`, etc. to layouts
- `@theme` vars in `app/assets/tailwind/application.css` define the default (synthwave) palette; `[data-theme="reggae|punk|jazz"]` blocks override the same `--color-*` vars
- `theme_controller.js` handles instant client-side switching (CSS var swap + font swap + server persist via JSON PATCH) and syncs the server-rendered `data-theme` attribute on Turbo navigations via `turbo:before-render`
- Users choose their theme on the profile edit page

### Adding a New Theme

1. Add an entry to `Themeable::THEMES` in `app/models/concerns/themeable.rb`
2. Add a `[data-theme="name"]` CSS block in `app/assets/tailwind/application.css` overriding `--color-*` and `--theme-*` vars

No template changes, no new controllers, no new routes.

## Key Patterns

### Playback Event Chain (Stimulus)

Three Stimulus controllers coordinate playback via custom DOM events:

```
song_row_controller  -->  queue_controller  -->  player_controller
   play()                   playNow()              playTrack()
   dispatches               manages queue           controls <audio>
   "queue:playNow"          in localStorage          element, MediaSession
   "queue:add"              dispatches               API, records
                            "player:play"            play history
```

- **Queue persistence**: localStorage keys `playerQueue` and `playerQueueIndex`
- **MediaSession API**: Enables native OS media controls (lock screen, etc.)

### ViewComponents

`TrackRow::Component` renders a track in list views with configurable options: `link_title`, `link_subtitle`, `show_album`, `hide_artist_if`, `show_duration`, `number`.

### Service Objects (app/services/)

- `JWTService` - Encode/decode JWT tokens
- `MetadataExtractor` - Parse audio file tags via WahWah (title, artist, album, year, genre, track_number, duration, bitrate, cover_art)
- `SearchService` - Text search across artists, albums, and tracks using LIKE patterns
- `NextTrackService` - Selects next track (shuffle/sequential) for radio stations, returns signed S3 URL
- `LiquidsoapConfigService` - Generates Liquidsoap `.liq` config from active radio stations

### Background Jobs (app/jobs/)

Three Solid Queue queues isolate work by resource profile (configured in `config/queue.yml`):

- **conversion** (2 threads) — CPU-heavy ffmpeg work: `AudioConversionJob`, `VideoConversionJob`, `StreamRecordingJob`
- **imports** (2 threads) — long-running network downloads: `MediaDownloadJob`, `VideoDownloadJob`, `YoutubeImportJob`
- **default** (3 threads) — everything else: `ChatResponseJob`, `MetadataExtractionJob`, `StationControlJob`, `StationListenerSyncJob`, `DownloadZipJob`, and other lightweight/quick jobs

When adding a new job, assign it to the appropriate queue via `queue_as` in the job class. Default is `:default` if omitted.

## Radio Stations (Icecast + Liquidsoap)

Playlist-based radio stations that stream continuously via Icecast.

### How It Works

```
User creates station from playlist
  -> RadioStation record (status: stopped)
  -> User clicks Start
  -> StationControlJob: generates Liquidsoap config, restarts Liquidsoap container
  -> Liquidsoap calls GET /api/internal/radio_stations/:id/next_track
  -> NextTrackService returns signed S3 URL
  -> Liquidsoap decodes + streams to Icecast mount point
  -> Listeners connect to https://radio.synthwaves.fm/<mount>.mp3
```

### Infrastructure

- **Icecast** (`moul/icecast`) — accepts source connections from Liquidsoap, serves streams to listeners. Reads `ICECAST_SOURCE_PASSWORD` and `ICECAST_ADMIN_PASSWORD` from env vars directly.
- **Liquidsoap** (`savonet/liquidsoap:v2.3.2`) — fetches tracks from Rails via internal API, transcodes to MP3, pushes to Icecast. Config is generated at `storage/liquidsoap/radio.liq`.
- Both run as Kamal accessories defined in `config/deploy.yml`.

### Key Files

- `app/models/radio_station.rb` — status tracking, mount points, crossfade settings
- `app/services/next_track_service.rb` — shuffle/sequential track selection with signed S3 URLs
- `app/services/liquidsoap_config_service.rb` — generates `.liq` config from active stations
- `app/controllers/api/internal/base_controller.rb` — Bearer token auth for Liquidsoap->Rails
- `app/controllers/api/internal/radio_stations_controller.rb` — next_track, notify, active endpoints
- `app/jobs/station_control_job.rb` — start/stop/skip lifecycle, restarts Liquidsoap via Docker socket
- `app/jobs/station_listener_sync_job.rb` — polls Icecast stats every 30s for listener counts

### Required Environment Variables

Set these in your shell before deploying (Kamal reads them via `.kamal/secrets`):

- `LIQUIDSOAP_API_TOKEN` — Bearer token for Liquidsoap->Rails internal API
- `ICECAST_SOURCE_PASSWORD` — Liquidsoap->Icecast authentication
- `ICECAST_ADMIN_PASSWORD` — Icecast admin interface

### Common Operations

```bash
# Restart Liquidsoap (picks up new config)
bin/kamal accessory stop liquidsoap
ssh <DEPLOY_HOST> "docker rm synthwaves_fm-liquidsoap"
bin/kamal accessory boot liquidsoap

# Regenerate Liquidsoap config from active stations
bin/kamal app exec -r job --interactive 'bin/rails runner "LiquidsoapConfigService.call"'

# Check Liquidsoap logs
bin/kamal accessory logs liquidsoap --lines 50

# Check Icecast logs
bin/kamal accessory logs icecast --lines 50

# Check if Liquidsoap can reach Icecast
bin/kamal accessory logs liquidsoap --lines 50 2>&1 | grep -i "error\|fail\|401"

# Verify config inside Liquidsoap container
ssh <DEPLOY_HOST> "docker exec synthwaves_fm-liquidsoap cat /rails/storage/liquidsoap/radio.liq"

# Fix stuck station status
bin/kamal app exec -r job --interactive 'bin/rails runner "RadioStation.find(ID).update(status: :active)"'
```

### Gotchas

- **Liquidsoap caches scripts.** If you update the config, you must destroy and recreate the container (stop + rm + boot), not just restart it.
- **Docker socket is scoped to the job role only.** The web server does not have Docker access. `StationControlJob` restarts Liquidsoap via the Docker socket.
- **Solid Queue runs only on the job server.** `SOLID_QUEUE_IN_PUMA` is not set — the web server does not process jobs.
- **Liquidsoap normalizes URLs by default**, which breaks S3 signed URLs with special characters. The config disables this with `settings.http.normalize_url.set(false)`.
- **All three env vars must be set in your shell when deploying.** If missing, Kamal writes empty strings into the container env files, causing auth failures between Liquidsoap, Icecast, and Rails.
- **After deploying, restart the job server** if you changed job classes: `bin/kamal app stop -r job && bin/kamal app boot -r job`.

## Routes

- Standard RESTful: artists, albums, tracks, playlists, favorites, play_histories
- `POST /albums/:id/create_playlist` - Create playlist from album
- `GET /tracks/:id/stream` - Audio streaming endpoint
- `GET /search`, `GET /search/dropdown` - Search
- `/rest/*`, `/api/rest/*` - Subsonic-compatible API (22 endpoints)
- `/api/v1/*` - JWT-authenticated REST API
- `/admin` - Madmin admin panel
- `/jobs` - Mission Control Jobs dashboard

## Git Workflow

Branch protection is enabled on `main` — direct pushes are not allowed. All changes must go through a pull request.

1. Create a feature branch from `main`
2. Commit changes to the branch
3. Push the branch and open a PR
4. CI must pass (tests, lint, security scans)
5. Merge via PR

## Testing

RSpec with FactoryBot, shoulda-matchers, and webmock. Test directories mirror app structure: `spec/{models,requests,services,jobs,components,helpers,factories}/`.
