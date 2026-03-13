# synthwaves.fm API Documentation

synthwaves.fm exposes three API layers for programmatic access to your music library.

## API Layers

| Layer | Base URL | Auth Method | Use Case |
|-------|----------|-------------|----------|
| [JWT API v1](jwt-api.md) | `/api/v1/` | JWT Bearer token | Native app bootstrap, token exchange |
| [Import API](import-api.md) | `/api/import/` | JWT Bearer token | Uploading tracks, videos, and playlists |
| [Subsonic API](subsonic/README.md) | `/rest/` or `/api/rest/` | Subsonic token/password | Subsonic-compatible client playback |

All three layers require authentication. See the [Authentication Guide](authentication.md) for details.

## API Key Management

API keys are managed through the web UI at `/api_keys`. Each key has a `client_id` (format: `bc_` + 32 hex characters) and a `secret_key` (shown once at creation). Keys can be created and revoked from the web interface.

## Endpoint Reference

### JWT API v1 (2 endpoints)

| Method | Path | Description | Doc |
|--------|------|-------------|-----|
| POST | `/api/v1/auth/token` | Exchange API key for JWT | [jwt-api.md](jwt-api.md#post-apiv1authtoken) |
| GET | `/api/v1/native/credentials` | Get user credentials for native app | [jwt-api.md](jwt-api.md#get-apiv1nativecredentials) |

### Import API (4 endpoints)

| Method | Path | Description | Doc |
|--------|------|-------------|-----|
| POST | `/api/import/direct_uploads` | Create a direct upload URL | [import-api.md](import-api.md#post-apiimportdirect_uploads) |
| POST | `/api/import/tracks` | Import a track | [import-api.md](import-api.md#post-apiimporttracks) |
| POST | `/api/import/playlists` | Import a playlist | [import-api.md](import-api.md#post-apiimportplaylists) |
| POST | `/api/import/videos` | Import a video | [import-api.md](import-api.md#post-apiimportvideos) |

### Subsonic API (30 endpoints)

| Endpoint | Description | Doc |
|----------|-------------|-----|
| `ping` | Test connectivity | [system.md](subsonic/system.md) |
| `getLicense` | Get server license | [system.md](subsonic/system.md) |
| `getMusicFolders` | List music folders | [browsing.md](subsonic/browsing.md) |
| `getIndexes` | Get artist index | [browsing.md](subsonic/browsing.md) |
| `getArtists` | List all artists | [browsing.md](subsonic/browsing.md) |
| `getArtist` | Get artist details | [browsing.md](subsonic/browsing.md) |
| `getAlbum` | Get album with tracks | [browsing.md](subsonic/browsing.md) |
| `getSong` | Get track details | [browsing.md](subsonic/browsing.md) |
| `stream` | Stream audio | [media.md](subsonic/media.md) |
| `download` | Download audio | [media.md](subsonic/media.md) |
| `getCoverArt` | Get album cover art | [media.md](subsonic/media.md) |
| `search3` | Search artists, albums, tracks | [search.md](subsonic/search.md) |
| `getAlbumList2` | List albums by criteria | [lists.md](subsonic/lists.md) |
| `getRandomSongs` | Get random tracks | [lists.md](subsonic/lists.md) |
| `getPlaylists` | List playlists | [playlists.md](subsonic/playlists.md) |
| `getPlaylist` | Get playlist with tracks | [playlists.md](subsonic/playlists.md) |
| `createPlaylist` | Create or update playlist | [playlists.md](subsonic/playlists.md) |
| `deletePlaylist` | Delete a playlist | [playlists.md](subsonic/playlists.md) |
| `star` | Favorite an item | [interaction.md](subsonic/interaction.md) |
| `unstar` | Unfavorite an item | [interaction.md](subsonic/interaction.md) |
| `getStarred2` | List favorites | [interaction.md](subsonic/interaction.md) |
| `scrobble` | Record a play | [interaction.md](subsonic/interaction.md) |
| `getVideos` | List videos | [video.md](subsonic/video.md) |
| `getVideo` | Get video details | [video.md](subsonic/video.md) |
| `videoStream` | Stream video | [video.md](subsonic/video.md) |
| `getVideoThumbnail` | Get video thumbnail | [video.md](subsonic/video.md) |
| `savePlaybackPosition` | Save video position | [video.md](subsonic/video.md) |
| `getPlaybackPosition` | Get video position | [video.md](subsonic/video.md) |
| `getFolders` | List video folders | [video.md](subsonic/video.md) |
| `getFolder` | Get folder with videos | [video.md](subsonic/video.md) |
