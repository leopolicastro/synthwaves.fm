# Import API

Four endpoints for importing tracks, videos, and playlists. All endpoints require JWT Bearer token authentication (see [Authentication](authentication.md)).

## POST `/api/import/direct_uploads`

Create a presigned direct upload URL for uploading files directly to storage.

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `filename` | string | Yes | Name of the file being uploaded |
| `byte_size` | integer | Yes | File size in bytes |
| `checksum` | string | Yes | Base64-encoded MD5 checksum of the file |
| `content_type` | string | No | MIME type (default: `video/mp4`) |

### Request

```bash
curl -X POST https://your-server/api/import/direct_uploads \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "filename": "song.mp3",
    "byte_size": 5242880,
    "checksum": "rL0Y20zC+Fzt72VPzMSk2A==",
    "content_type": "audio/mpeg"
  }'
```

### Response — 201 Created

```json
{
  "signed_id": "eyJfcmFpbHMiOnsi...",
  "direct_upload": {
    "url": "https://storage.example.com/uploads/...",
    "headers": {
      "Content-Type": "audio/mpeg",
      "Content-MD5": "rL0Y20zC+Fzt72VPzMSk2A=="
    }
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `signed_id` | string | Signed blob ID to pass to track/video import |
| `direct_upload.url` | string | PUT URL for uploading the file |
| `direct_upload.headers` | object | Headers to include with the PUT request |

### Errors

| Status | Body | Cause |
|--------|------|-------|
| 422 | `{"error": "..."}` | Invalid parameters |

---

## POST `/api/import/tracks`

Import a track. Supports two upload modes: direct upload (using a previously uploaded blob) or multipart file upload.

### Mode 1: Direct Upload

Use after obtaining a `signed_id` from the direct uploads endpoint.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `signed_blob_id` | string | Yes | Signed blob ID from direct upload |
| `title` | string | No | Track title (falls back to filename) |
| `artist` | string | No | Artist name (default: `Unknown Artist`) |
| `album` | string | No | Album title (default: `Unknown Album`) |
| `year` | integer | No | Release year |
| `genre` | string | No | Genre |
| `track_number` | integer | No | Track number |
| `disc_number` | integer | No | Disc number |
| `duration` | float | No | Duration in seconds |
| `bitrate` | integer | No | Bitrate in kbps |
| `file_format` | string | No | File format (e.g., `mp3`, `flac`) |
| `cover_art` | string | No | Base64-encoded cover art image data |
| `cover_art_mime_type` | string | No | MIME type of cover art (required if `cover_art` provided) |

### Mode 2: Multipart Upload

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `audio_file` | file | Yes | Audio file (multipart form data) |

Metadata is automatically extracted from the audio file tags.

### Request (Direct Upload)

```bash
curl -X POST https://your-server/api/import/tracks \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "signed_blob_id": "eyJfcmFpbHMiOnsi...",
    "title": "My Song",
    "artist": "Artist Name",
    "album": "Album Title",
    "file_format": "mp3"
  }'
```

### Request (Multipart)

```bash
curl -X POST https://your-server/api/import/tracks \
  -H "Authorization: Bearer <token>" \
  -F "audio_file=@/path/to/song.mp3"
```

### Response — 201 Created

```json
{
  "id": 42,
  "title": "My Song",
  "artist": "Artist Name",
  "album": "Album Title",
  "created": true
}
```

| Field | Type | Description |
|-------|------|-------------|
| `id` | integer | Track ID |
| `title` | string | Track title |
| `artist` | string | Artist name |
| `album` | string | Album title |
| `created` | boolean | `true` if new, `false` if duplicate |

A duplicate track (same title, album, artist, and track number with an attached audio file) returns `200` with `"created": false`.

### Errors

| Status | Body | Cause |
|--------|------|-------|
| 422 | `{"error": "audio_file or signed_blob_id is required"}` | Neither upload mode specified |
| 422 | `{"error": "..."}` | Validation failure |
| 503 | `{"error": "Upload failed: ..."}` | Storage error during file attachment |

---

## POST `/api/import/playlists`

Import a playlist by matching track metadata against existing tracks in the library. Matching is case-insensitive on title, artist, and album.

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | Yes | Playlist name (must be unique) |
| `tracks` | array | No | Array of track objects to match |
| `tracks[].title` | string | Yes | Track title |
| `tracks[].artist` | string | Yes | Artist name |
| `tracks[].album` | string | Yes | Album title |

### Request

```bash
curl -X POST https://your-server/api/import/playlists \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Road Trip",
    "tracks": [
      {"title": "Song One", "artist": "Artist A", "album": "Album X"},
      {"title": "Song Two", "artist": "Artist B", "album": "Album Y"}
    ]
  }'
```

### Response — 201 Created

```json
{
  "id": 7,
  "name": "Road Trip",
  "tracks_matched": 1,
  "tracks_not_found": 1,
  "not_found": [
    {"title": "Song Two", "artist": "Artist B", "album": "Album Y"}
  ]
}
```

| Field | Type | Description |
|-------|------|-------------|
| `id` | integer | Playlist ID |
| `name` | string | Playlist name |
| `tracks_matched` | integer | Number of tracks successfully matched and added |
| `tracks_not_found` | integer | Number of tracks that couldn't be matched |
| `not_found` | array | Details of unmatched tracks |

### Errors

| Status | Body | Cause |
|--------|------|-------|
| 422 | `{"error": "name is required"}` | Missing playlist name |
| 409 | `{"error": "Playlist 'X' already exists"}` | Duplicate playlist name |

---

## POST `/api/import/videos`

Import a video using a previously uploaded blob from the direct uploads endpoint.

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `signed_blob_id` | string | Yes | Signed blob ID from direct upload |
| `title` | string | No | Video title (falls back to filename) |
| `folder_name` | string | No | Folder name (created if it doesn't exist) |
| `season_number` | integer | No | Season number |
| `episode_number` | integer | No | Episode number |

### Request

```bash
curl -X POST https://your-server/api/import/videos \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "signed_blob_id": "eyJfcmFpbHMiOnsi...",
    "title": "Episode 1",
    "folder_name": "My Series",
    "season_number": 1,
    "episode_number": 1
  }'
```

### Response — 201 Created

```json
{
  "id": 15,
  "title": "Episode 1",
  "folder": "My Series",
  "status": "processing"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `id` | integer | Video ID |
| `title` | string | Video title |
| `folder` | string | Folder name (null if no folder) |
| `status` | string | Processing status (`processing` on creation) |

### Errors

| Status | Body | Cause |
|--------|------|-------|
| 422 | `{"error": "Invalid signed blob ID"}` | Bad or expired `signed_blob_id` |
| 422 | `{"error": "..."}` | Validation failure |
