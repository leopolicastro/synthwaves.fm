# Lists

## `getAlbumList2`

Returns a list of albums matching the given criteria.

**Path:** `/rest/getAlbumList2`

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `type` | string | No | `alphabeticalByName` | Sort/filter type (see below) |
| `size` | integer | No | 10 | Number of albums to return (1–500) |
| `offset` | integer | No | 0 | Number of albums to skip (for pagination) |
| `fromYear` | integer | Conditional | — | Required when `type=byYear` |
| `toYear` | integer | Conditional | — | Required when `type=byYear` |
| `genre` | string | Conditional | — | Required when `type=byGenre` |

### Supported Types

| Type | Description |
|------|-------------|
| `newest` | Most recently added albums |
| `random` | Random album order |
| `alphabeticalByName` | Sorted by album title |
| `alphabeticalByArtist` | Sorted by artist name |
| `byYear` | Filtered and sorted by year range (`fromYear`–`toYear`) |
| `byGenre` | Filtered by genre |

### Response

```json
{
  "subsonic-response": {
    ...
    "albumList2": {
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

Albums use the standard [album shape](README.md#album).

---

## `getRandomSongs`

Returns random tracks from the library.

**Path:** `/rest/getRandomSongs`

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `size` | integer | No | 10 | Number of tracks to return (1–500) |

### Response

```json
{
  "subsonic-response": {
    ...
    "randomSongs": {
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

Tracks use the standard [child shape](README.md#child-track).
