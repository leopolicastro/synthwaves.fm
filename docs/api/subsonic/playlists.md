# Playlists

synthwaves.fm includes two virtual playlists (`all` and `podcasts`) alongside user-created playlists. Virtual playlists cannot be modified or deleted.

## `getPlaylists`

Returns all playlists, including virtual playlists.

**Path:** `/rest/getPlaylists`

**Parameters:** [Common params](README.md#required-common-parameters) only.

### Response

```json
{
  "subsonic-response": {
    ...
    "playlists": {
      "playlist": [
        {
          "id": "all",
          "name": "All Tracks",
          "songCount": 150,
          "duration": 36000,
          "owner": "user@example.com",
          "public": false
        },
        {
          "id": "podcasts",
          "name": "Podcasts",
          "songCount": 10,
          "duration": 7200,
          "owner": "user@example.com",
          "public": false
        },
        {
          "id": "7",
          "name": "Road Trip",
          "songCount": 25,
          "duration": 5400,
          "owner": "user@example.com",
          "public": false
        }
      ]
    }
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Playlist ID (`all` and `podcasts` are virtual) |
| `name` | string | Playlist name |
| `songCount` | integer | Number of streamable tracks |
| `duration` | integer | Total duration in seconds |
| `owner` | string | Owner's email address |
| `public` | boolean | Always `false` |

---

## `getPlaylist`

Returns a playlist with its tracks.

**Path:** `/rest/getPlaylist`

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | Playlist ID (numeric, `all`, or `podcasts`) |

### Response

```json
{
  "subsonic-response": {
    ...
    "playlist": {
      "id": "7",
      "name": "Road Trip",
      "songCount": 25,
      "duration": 5400,
      "owner": "user@example.com",
      "public": false,
      "entry": [
        {
          "id": "42",
          "parent": "5",
          "isDir": false,
          "title": "Xtal",
          "album": "Selected Ambient Works",
          "artist": "Aphex Twin",
          "duration": 290,
          "albumId": "5",
          "artistId": "1",
          "type": "music"
        }
      ]
    }
  }
}
```

Entries use the standard [child shape](README.md#child-track). For user-created playlists, entries are ordered by position. The `all` virtual playlist returns all music tracks alphabetically. The `podcasts` virtual playlist returns the 5 most recent episodes per podcast, ordered by newest first.

### Errors

| Code | Message | Cause |
|------|---------|-------|
| 70 | Playlist not found | Invalid playlist ID |

---

## `createPlaylist`

Creates a new playlist or updates an existing one. When song IDs are provided, the playlist's tracks are replaced entirely.

**Path:** `/rest/createPlaylist`

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | Conditional | Playlist name (required for new playlists, optional for updates) |
| `playlistId` | string | No | Existing playlist ID to update |
| `songId` | string/array | No | Track ID(s) to set as the playlist contents. Replaces all existing tracks. |

To create a new playlist:

```
/rest/createPlaylist?name=My+Playlist&songId=42&songId=43&...
```

To update an existing playlist's tracks:

```
/rest/createPlaylist?playlistId=7&songId=42&songId=43&...
```

### Response

```json
{
  "subsonic-response": {
    ...
    "playlist": {
      "id": "7",
      "name": "My Playlist",
      "songCount": 2,
      "duration": 480,
      "owner": "user@example.com",
      "public": false
    }
  }
}
```

### Errors

| Code | Message | Cause |
|------|---------|-------|
| 70 | Playlist not found | Invalid `playlistId` |
| 70 | Cannot modify a virtual playlist | `playlistId` is `all` or `podcasts` |

---

## `deletePlaylist`

Deletes a playlist.

**Path:** `/rest/deletePlaylist`

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | Playlist ID to delete |

### Response

Returns an empty success response.

```json
{
  "subsonic-response": {
    "status": "ok",
    "version": "1.16.1",
    ...
  }
}
```

### Errors

| Code | Message | Cause |
|------|---------|-------|
| 70 | Playlist not found | Invalid playlist ID |
| 70 | Cannot delete a virtual playlist | ID is `all` or `podcasts` |
