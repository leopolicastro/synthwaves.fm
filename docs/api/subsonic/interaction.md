# Interaction

## `star`

Adds items to the user's favorites. Supports starring tracks, albums, and artists in a single request. Items already starred are silently ignored.

**Path:** `/rest/star`

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string/array | No | Track ID(s) to star |
| `albumId` | string/array | No | Album ID(s) to star |
| `artistId` | string/array | No | Artist ID(s) to star |

At least one parameter should be provided.

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

---

## `unstar`

Removes items from the user's favorites.

**Path:** `/rest/unstar`

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string/array | No | Track ID(s) to unstar |
| `albumId` | string/array | No | Album ID(s) to unstar |
| `artistId` | string/array | No | Artist ID(s) to unstar |

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

---

## `getStarred2`

Returns all starred (favorited) artists, albums, and tracks.

**Path:** `/rest/getStarred2`

**Parameters:** [Common params](README.md#required-common-parameters) only.

### Response

```json
{
  "subsonic-response": {
    ...
    "starred2": {
      "artist": [
        {
          "id": "1",
          "name": "Aphex Twin",
          "albumCount": 5,
          "starred": "2024-01-15T10:30:00Z"
        }
      ],
      "album": [
        {
          "id": "5",
          "name": "Selected Ambient Works",
          "artist": "Aphex Twin",
          "artistId": "1",
          "songCount": 12,
          "duration": 2940,
          "year": 1992,
          "coverArt": "5",
          "starred": "2024-01-15T10:30:00Z"
        }
      ],
      "song": [
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
          "type": "music",
          "starred": "2024-01-15T10:30:00Z"
        }
      ]
    }
  }
}
```

Each item includes a `starred` field (ISO 8601 timestamp) in addition to the standard shape. Albums use the [album shape](README.md#album). Tracks use the [child shape](README.md#child-track).

---

## `scrobble`

Records a play event for a track, creating a play history entry.

**Path:** `/rest/scrobble`

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | Track ID |

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
| 70 | Song not found | Invalid track ID |
