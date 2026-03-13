# synthwaves.fm

[![Certified Shovelware](https://justin.searls.co/img/shovelware.svg)](https://justin.searls.co/shovelware/)

Self-hosted music streaming for your personal library.

## What is synthwaves.fm?

synthwaves.fm is a self-hosted music streaming app built with Rails. Upload your music library, organize it by artist, album, and genre, and stream it from any device. It installs as a Progressive Web App for a native feel, works with Subsonic-compatible music apps, and keeps your music and podcasts neatly separated.

## Features

### Music Library

- Browse by artist, album, track, or podcast
- Album pages with cover art and sortable track lists
- Full-text search with live dropdown suggestions
- Filter by genre, year range, and favorites
- Automatic metadata extraction from uploaded audio files

### Player

- Full playback controls: play/pause, next/previous, seek, volume
- Shuffle and repeat modes (off / all / one)
- Persistent queue that survives page reloads and browser restarts
- Resume playback position across sessions
- Native OS media controls (lock screen, media keys) via MediaSession API

### Playlists & Favorites

- Create playlists and reorder tracks with drag-and-drop
- One-click playlist creation from any album
- Favorite any artist, album, or track
- Recently played and recently added sections on the home page

### YouTube Integration

- Import YouTube playlists as music or podcasts
- Create radio stations from YouTube live streams
- Stream YouTube audio alongside your local library

### Progressive Web App

- Install on mobile or desktop for a native app experience
- Standalone display mode with custom icons and dark theme

## Use Your Favorite Apps

synthwaves.fm implements the Subsonic API, so you can connect dedicated music apps and stream your library from any platform. Popular compatible apps include DSub, play:Sub, Submariner, Clementine, Symfonium, cliamp, and many more.

There's also a REST API with JWT authentication for building your own integrations. API keys are manageable from the web UI under your account settings.

## Getting Started

**Requirements:** Ruby 4.0.1+, SQLite3, ffmpeg (for audio conversion)

**Setup and run:**

```
bin/setup
```

This installs dependencies, prepares the database, and starts the server.

For subsequent launches, start the dev server with:

```
bin/dev
```

**Default login:** admin@example.com / abc123

## Uploading Your Library

Once your server is running, use these rake tasks to upload music and playlists from your local machine. Both require an API key — create one from the web UI under your account settings.

### Push Music

Upload a directory of audio files (mp3, flac, ogg, m4a, aac, wav, wma, opus, webm):

```
GROOVY_REMOTE_URL=https://groovy.example.com \
GROOVY_CLIENT_ID=bc_xxxx \
GROOVY_SECRET_KEY=xxxx \
MUSIC_PATH=/path/to/music \
bundle exec rake library:push
```

`MUSIC_PATH` defaults to `/Volumes/music` if not set. Metadata and cover art are extracted automatically. Duplicate tracks are skipped.

### Push cliamp Playlists

Upload playlists from cliamp's TOML playlist files:

```
GROOVY_REMOTE_URL=https://groovy.example.com \
GROOVY_CLIENT_ID=bc_xxxx \
GROOVY_SECRET_KEY=xxxx \
CLIAMP_PLAYLISTS_PATH=~/.config/cliamp/playlists \
bundle exec rake playlists:push
```

`CLIAMP_PLAYLISTS_PATH` defaults to `~/.config/cliamp/playlists`. Tracks are matched against your existing library by title, artist, and album. YouTube-only tracks are filtered out. Duplicate playlists are skipped.

---

Built with Rails 8, Hotwire, Tailwind CSS, and ViewComponent. Generated with [Boilercode](https://boilercode.io).
