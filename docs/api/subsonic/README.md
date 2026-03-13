# Subsonic API

synthwaves.fm implements a Subsonic-compatible API (version 1.16.1) with OpenSubsonic extensions. This allows any Subsonic-compatible client to stream music and videos from your library.

## Base URL

The API is available at two route prefixes for client compatibility:

- `/rest/<endpoint>` — Standard Subsonic path
- `/api/rest/<endpoint>` — Alternative path

All endpoints accept an optional `.view` suffix (e.g., `/rest/ping.view`). Both `GET` and `POST` methods are accepted for every endpoint.

## Authentication

Every request must include authentication parameters. See the [Authentication Guide](../authentication.md#subsonic-authentication) for full details.

### Required Common Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `u` | string | Yes | Username (email address) |
| `t` | string | Conditional | MD5 token (`MD5(password + salt)`) — required unless `p` is used |
| `s` | string | Conditional | Random salt — required with `t` |
| `p` | string | Conditional | Plaintext password (optional `enc:` hex prefix) — required unless `t`/`s` are used |
| `v` | string | Yes | API version (e.g., `1.16.1`) |
| `c` | string | Yes | Client name identifier |
| `f` | string | No | Response format: `json` or `xml` (default: `xml`) |

## Response Format

### JSON Envelope

All successful JSON responses are wrapped in a `subsonic-response` object:

```json
{
  "subsonic-response": {
    "status": "ok",
    "version": "1.16.1",
    "type": "synthwaves.fm",
    "serverVersion": "0.1.0",
    "openSubsonic": true,
    ...
  }
}
```

### XML Envelope

```xml
<?xml version="1.0" encoding="UTF-8"?>
<subsonic-response status="ok" version="1.16.1" type="synthwaves.fm" serverVersion="0.1.0" openSubsonic="true">
  ...
</subsonic-response>
```

### Error Responses

Error responses set `status` to `"failed"` and include an `error` object:

```json
{
  "subsonic-response": {
    "status": "failed",
    "version": "1.16.1",
    "type": "synthwaves.fm",
    "error": { "code": 70, "message": "Song not found" }
  }
}
```

### Error Codes

| Code | Meaning |
|------|---------|
| 40 | Wrong username or password |
| 70 | Resource not found |

## Entity Shapes

These are the standard shapes returned by various endpoints. Fields with no value are omitted.

### `child` (Track)

Returned by `getSong`, `getAlbum` (as `song`), `search3` (as `song`), `getRandomSongs`, `getPlaylist` (as `entry`), and `getStarred2` (as `song`).

```json
{
  "id": "42",
  "parent": "5",
  "isDir": false,
  "title": "Track Title",
  "album": "Album Title",
  "artist": "Artist Name",
  "track": 3,
  "year": 2023,
  "genre": "Electronic",
  "size": 8541234,
  "contentType": "audio/mpeg",
  "suffix": "mp3",
  "duration": 245,
  "bitRate": 320,
  "albumId": "5",
  "artistId": "2",
  "type": "music"
}
```

### `album`

Returned by `getArtist` (as `album`), `getAlbum`, `getAlbumList2`, `search3`, and `getStarred2`.

```json
{
  "id": "5",
  "name": "Album Title",
  "artist": "Artist Name",
  "artistId": "2",
  "songCount": 12,
  "duration": 2940,
  "year": 2023,
  "genre": "Electronic",
  "coverArt": "5"
}
```

### `video`

Returned by `getVideos`, `getVideo`, and `getFolder`.

```json
{
  "id": "15",
  "title": "Video Title",
  "description": "A description",
  "duration": 3600,
  "width": 1920,
  "height": 1080,
  "size": 1073741824,
  "contentType": "video/mp4",
  "fileFormat": "mp4",
  "folderId": "3",
  "folderName": "My Series",
  "episodeNumber": 1,
  "seasonNumber": 1,
  "created": "2024-01-15T10:30:00Z"
}
```

## Endpoint Documentation

- [System](system.md) — `ping`, `getLicense`
- [Browsing](browsing.md) — `getMusicFolders`, `getIndexes`, `getArtists`, `getArtist`, `getAlbum`, `getSong`
- [Media](media.md) — `stream`, `download`, `getCoverArt`
- [Search](search.md) — `search3`
- [Lists](lists.md) — `getAlbumList2`, `getRandomSongs`
- [Playlists](playlists.md) — `getPlaylists`, `getPlaylist`, `createPlaylist`, `deletePlaylist`
- [Interaction](interaction.md) — `star`, `unstar`, `getStarred2`, `scrobble`
- [Video](video.md) — `getVideos`, `getVideo`, `videoStream`, `getVideoThumbnail`, `savePlaybackPosition`, `getPlaybackPosition`, `getFolders`, `getFolder`
