# Synthwaves.fm

Music streaming web application built with Rails 8.

## Common Commands

```bash
bin/dev                  # Start dev server (Rails + Tailwind watcher)
bin/rspec                # Run full test suite
bin/rspec spec/models/   # Run model specs only
bin/rails db:migrate     # Run migrations
bin/rails db:seed        # Seed database
bin/setup                # Install deps, prepare DB, start server
bundle exec rubocop      # Lint Ruby code
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
- **Flipper** for feature flags

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
  has_many :playlists, :favorites, :play_histories, :api_keys, :sessions
  has_secure_password

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

`TrackRowComponent` renders a track in list views with configurable options: `link_title`, `link_subtitle`, `show_album`, `hide_artist_if`, `show_duration`, `number`.

### Service Objects (app/services/)

- `JWTService` - Encode/decode JWT tokens
- `MetadataExtractor` - Parse audio file tags via WahWah (title, artist, album, year, genre, track_number, duration, bitrate, cover_art)
- `SearchService` - Text search across artists, albums, and tracks using LIKE patterns

### Background Jobs (app/jobs/)

- `AudioConversionJob` - Converts non-MP3 formats to MP3 via ffmpeg at 192k bitrate, then re-extracts metadata
- `MetadataExtractionJob` - Extracts and saves audio metadata on upload
- `ChatResponseJob` - Streams AI responses via ActionCable

## Routes

- Standard RESTful: artists, albums, tracks, playlists, favorites, play_histories
- `POST /albums/:id/create_playlist` - Create playlist from album
- `GET /tracks/:id/stream` - Audio streaming endpoint
- `GET /search`, `GET /search/dropdown` - Search
- `/rest/*`, `/api/rest/*` - Subsonic-compatible API (22 endpoints)
- `/api/v1/*` - JWT-authenticated REST API
- `/admin` - Madmin admin panel
- `/jobs` - Mission Control Jobs dashboard

## Testing

RSpec with FactoryBot, shoulda-matchers, and webmock. Test directories mirror app structure: `spec/{models,requests,services,jobs,components,helpers,factories}/`.
