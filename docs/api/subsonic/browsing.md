# Browsing

## `getMusicFolders`

Returns a static list of music folders. synthwaves.fm uses a single folder.

**Path:** `/rest/getMusicFolders`

**Parameters:** [Common params](README.md#required-common-parameters) only.

### Response

```json
{
  "subsonic-response": {
    "status": "ok",
    "version": "1.16.1",
    ...
    "musicFolders": {
      "musicFolder": [
        { "id": 1, "name": "Music" }
      ]
    }
  }
}
```

---

## `getIndexes`

Returns an alphabetical index of all artists.

**Path:** `/rest/getIndexes`

**Parameters:** [Common params](README.md#required-common-parameters) only.

### Response

```json
{
  "subsonic-response": {
    ...
    "indexes": {
      "index": [
        {
          "name": "A",
          "artist": [
            { "id": "1", "name": "Aphex Twin" },
            { "id": "2", "name": "Autechre" }
          ]
        },
        {
          "name": "B",
          "artist": [
            { "id": "3", "name": "Boards of Canada" }
          ]
        }
      ]
    }
  }
}
```

---

## `getArtists`

Returns all artists grouped alphabetically, with album counts.

**Path:** `/rest/getArtists`

**Parameters:** [Common params](README.md#required-common-parameters) only.

### Response

```json
{
  "subsonic-response": {
    ...
    "artists": {
      "index": [
        {
          "name": "A",
          "artist": [
            { "id": "1", "name": "Aphex Twin", "albumCount": 5 }
          ]
        }
      ]
    }
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `artist.id` | string | Artist ID |
| `artist.name` | string | Artist name |
| `artist.albumCount` | integer | Number of albums |

---

## `getArtist`

Returns an artist and their albums.

**Path:** `/rest/getArtist`

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | Artist ID |

### Response

```json
{
  "subsonic-response": {
    ...
    "artist": {
      "id": "1",
      "name": "Aphex Twin",
      "albumCount": 3,
      "album": [
        {
          "id": "5",
          "name": "Selected Ambient Works",
          "artist": "Aphex Twin",
          "artistId": "1",
          "songCount": 12,
          "duration": 2940,
          "year": 1992,
          "genre": "Electronic",
          "coverArt": "5"
        }
      ]
    }
  }
}
```

Albums are returned using the standard [album shape](README.md#album).

### Errors

| Code | Message | Cause |
|------|---------|-------|
| 70 | Artist not found | Invalid artist ID |

---

## `getAlbum`

Returns an album with its tracks.

**Path:** `/rest/getAlbum`

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | Album ID |

### Response

```json
{
  "subsonic-response": {
    ...
    "album": {
      "id": "5",
      "name": "Selected Ambient Works",
      "artist": "Aphex Twin",
      "artistId": "1",
      "songCount": 12,
      "duration": 2940,
      "year": 1992,
      "genre": "Electronic",
      "coverArt": "5",
      "song": [
        {
          "id": "42",
          "parent": "5",
          "isDir": false,
          "title": "Xtal",
          "album": "Selected Ambient Works",
          "artist": "Aphex Twin",
          "track": 1,
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

Tracks are ordered by disc number then track number. Each track uses the standard [child shape](README.md#child-track).

### Errors

| Code | Message | Cause |
|------|---------|-------|
| 70 | Album not found | Invalid album ID |

---

## `getSong`

Returns a single track.

**Path:** `/rest/getSong`

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | Track ID |

### Response

```json
{
  "subsonic-response": {
    ...
    "song": {
      "id": "42",
      "parent": "5",
      "isDir": false,
      "title": "Xtal",
      "album": "Selected Ambient Works",
      "artist": "Aphex Twin",
      "track": 1,
      "year": 1992,
      "genre": "Electronic",
      "size": 8541234,
      "contentType": "audio/mpeg",
      "suffix": "mp3",
      "duration": 290,
      "bitRate": 320,
      "albumId": "5",
      "artistId": "1",
      "type": "music"
    }
  }
}
```

Uses the standard [child shape](README.md#child-track).

### Errors

| Code | Message | Cause |
|------|---------|-------|
| 70 | Song not found | Invalid track ID or track has no streamable audio |
