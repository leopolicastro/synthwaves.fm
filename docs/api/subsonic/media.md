# Media

## `stream`

Streams the audio file for a track. Redirects to the audio file URL.

**Path:** `/rest/stream`

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | Track ID |

### Response

Returns a `302` redirect to the audio file URL. The client should follow the redirect to receive the audio data.

### Errors

| Code | Message | Cause |
|------|---------|-------|
| 70 | Song not found | Invalid track ID or no audio file attached |

---

## `download`

Downloads the audio file for a track. Behaves identically to `stream`.

**Path:** `/rest/download`

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | Track ID |

### Response

Returns a `302` redirect to the audio file URL.

### Errors

| Code | Message | Cause |
|------|---------|-------|
| 70 | Song not found | Invalid track ID or no audio file attached |

---

## `getCoverArt`

Returns the cover art image for an album. Redirects to the image URL.

**Path:** `/rest/getCoverArt`

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | Album ID |

### Response

Returns a `302` redirect to the cover art image URL. If no cover art is attached, returns `404 Not Found`.

### Errors

Returns HTTP `404` (not a Subsonic error envelope) if the album is not found or has no cover image.
