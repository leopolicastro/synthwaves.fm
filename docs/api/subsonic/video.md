# Video

These endpoints extend the Subsonic API with video management capabilities.

## `getVideos`

Returns a list of videos, optionally filtered by folder or search query.

**Path:** `/rest/getVideos`

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `folderId` | string | No | Filter by folder ID |
| `query` | string | No | Search query to filter videos |

Only videos with `ready` status are returned.

### Response

```json
{
  "subsonic-response": {
    ...
    "videos": {
      "video": [
        {
          "id": "15",
          "title": "Episode 1",
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
      ]
    }
  }
}
```

Videos use the standard [video shape](README.md#video).

---

## `getVideo`

Returns details for a single video.

**Path:** `/rest/getVideo`

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | Video ID |

### Response

```json
{
  "subsonic-response": {
    ...
    "video": {
      "id": "15",
      "title": "Episode 1",
      "duration": 3600,
      ...
    }
  }
}
```

Uses the standard [video shape](README.md#video).

### Errors

| Code | Message | Cause |
|------|---------|-------|
| 70 | Video not found | Invalid video ID |

---

## `videoStream`

Streams the video file. Redirects to the video file URL. Only videos with `ready` status can be streamed.

**Path:** `/rest/videoStream`

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | Video ID |

### Response

Returns a `302` redirect to the video file URL.

### Errors

| Code | Message | Cause |
|------|---------|-------|
| 70 | Video not found | Invalid video ID, not ready, or no file attached |

---

## `getVideoThumbnail`

Returns the thumbnail image for a video. Optionally resize to a specific size.

**Path:** `/rest/getVideoThumbnail`

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | Video ID |
| `size` | integer | No | Resize to square dimensions (e.g., `200` for 200x200) |

### Response

Returns a `302` redirect to the thumbnail image URL. If `size` is specified, redirects to a resized variant. Returns `404` if no thumbnail is attached.

### Errors

Returns HTTP `404` (not a Subsonic error envelope) if the video or thumbnail is not found.

---

## `savePlaybackPosition`

Saves the current playback position for a video. Used for resume functionality.

**Path:** `/rest/savePlaybackPosition`

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | Video ID |
| `position` | float | Yes | Playback position in seconds |

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
| 70 | Video not found | Invalid video ID |

---

## `getPlaybackPosition`

Returns the saved playback position for a video. Returns `0` if no position has been saved.

**Path:** `/rest/getPlaybackPosition`

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | Video ID |

### Response

```json
{
  "subsonic-response": {
    ...
    "playbackPosition": {
      "id": "15",
      "position": 1234.5
    }
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Video ID |
| `position` | float | Playback position in seconds (0 if never saved) |

### Errors

| Code | Message | Cause |
|------|---------|-------|
| 70 | Video not found | Invalid video ID |

---

## `getFolders`

Returns all video folders with their video counts.

**Path:** `/rest/getFolders`

**Parameters:** [Common params](README.md#required-common-parameters) only.

### Response

```json
{
  "subsonic-response": {
    ...
    "folders": {
      "folder": [
        {
          "id": "3",
          "name": "My Series",
          "videoCount": 12
        }
      ]
    }
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Folder ID |
| `name` | string | Folder name |
| `videoCount` | integer | Number of ready videos in the folder |

---

## `getFolder`

Returns a folder with its videos.

**Path:** `/rest/getFolder`

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | Folder ID |

### Response

```json
{
  "subsonic-response": {
    ...
    "folder": {
      "id": "3",
      "name": "My Series",
      "video": [
        {
          "id": "15",
          "title": "Episode 1",
          "duration": 3600,
          ...
        }
      ]
    }
  }
}
```

Videos use the standard [video shape](README.md#video). Only videos with `ready` status are included.

### Errors

| Code | Message | Cause |
|------|---------|-------|
| 70 | Folder not found | Invalid folder ID |
