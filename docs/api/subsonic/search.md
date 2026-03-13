# Search

## `search3`

Search across artists, albums, and tracks using a text query. Matches are case-insensitive and use `LIKE` pattern matching.

**Path:** `/rest/search3`

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `query` | string | Yes | — | Search query |
| `artistCount` | integer | No | 20 | Maximum number of artists to return |
| `albumCount` | integer | No | 20 | Maximum number of albums to return |
| `songCount` | integer | No | 20 | Maximum number of tracks to return |

### Response

```json
{
  "subsonic-response": {
    ...
    "searchResult3": {
      "artist": [
        { "id": "1", "name": "Aphex Twin", "albumCount": 5 }
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
          "genre": "Electronic",
          "coverArt": "5"
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
          "type": "music"
        }
      ]
    }
  }
}
```

Albums use the standard [album shape](README.md#album). Tracks use the standard [child shape](README.md#child-track).
