# iOS Native App: Audio Playback Start Time Optimization

## Problem

When playing a song on cellular, there's a 1-3 second delay before audio starts. This affects the native iOS app which uses AVPlayer for audio playback.

## Current Flow (Native App)

1. User taps a track in the Turbo Native web view
2. `song_row_controller.js` dispatches `queue:playNow` with track data
3. `bridge/playback_controller.js` intercepts the event (via capture phase), calls `this.send("playTrack", { track })` to the native side
4. The native app receives the track with a **Subsonic API stream URL** (e.g., `/rest/stream?id=123&u=...&t=...&s=...`)
5. AVPlayer loads the URL, which returns a **302 redirect** to a presigned Linode/S3 URL
6. AVPlayer follows the redirect and begins playback

## Where the Latency Lives

On cellular, the bottleneck is likely in one or more of these:

### 1. Subsonic URL Construction (Web Side)
The `SubsonicUrlBuilder` generates authenticated stream URLs that point to the Rails server (`/rest/stream`). The native app must first hit the Rails server, which then redirects to S3. This adds a full round trip through the Rails app on every play.

**Current path**: Native App -> Rails `/rest/stream` (302) -> Linode S3 (200 audio)

### 2. AVPlayer Buffering Strategy
AVPlayer's default `automaticallyWaitsToMinimizeStalling` behavior may buffer more data than necessary before starting playback, especially on cellular where it detects lower bandwidth.

### 3. DNS + TLS Cold Start
The first request to Linode S3 requires DNS resolution + TLS handshake, which can take 300-1000ms on cellular.

## Recommended Optimizations

### Option A: Pre-resolve the S3 URL on the Web Side (Recommended)

Instead of giving the native app a Subsonic stream URL that 302-redirects, resolve the presigned S3 URL on the Rails side and pass it directly.

**Implementation:**

1. Add a new field to the bridge track data — e.g., `directStreamURL`
2. In the Rails view/component where `native_url_builder.stream_url(track)` is called, also compute the direct S3 URL:
   ```ruby
   # In TrackRowComponent or wherever native track data is set
   direct_url = track.audio_file.blob.url(expires_in: 1.hour)
   ```
3. In `bridge/playback_controller.js`, include it in `buildNativeTrack`:
   ```js
   directStreamURL: detail.nativeDirectStreamUrl || ""
   ```
4. On the native side, prefer `directStreamURL` when available, falling back to `streamURL`

**Result**: Eliminates the 302 redirect hop through Rails entirely. The native app goes straight to S3.

**Trade-off**: Presigned URLs expire (1 hour). If a track sits in the queue for >1 hour, the URL will 403. The native player should handle this by falling back to the Subsonic URL or requesting a fresh URL.

### Option B: DNS Pre-warming on the Native Side

Pre-resolve the S3 endpoint hostname when the app launches, so the DNS cache is warm by the time the user plays a track.

**Implementation:**

1. On app launch, make a lightweight request (e.g., HEAD) to the S3 endpoint to warm DNS + TLS
2. The S3 endpoint hostname can be provided via the `/api/v1/native/credentials` endpoint (add a `storage_endpoint` field)
3. Alternatively, use `URLSession` prefetch or `nw_connection_t` for speculative DNS resolution

**Web-side change** (add to `NativeController#credentials`):
```ruby
def credentials
  render json: {
    email: Current.user.email_address,
    subsonic_password: Current.user.subsonic_password,
    theme: Current.user.theme,
    storage_endpoint: storage_endpoint
  }
end

private

def storage_endpoint
  service = ActiveStorage::Blob.service
  service = service.primary if service.respond_to?(:primary)
  return unless service.respond_to?(:bucket)
  service.bucket.client.config.endpoint.to_s
end
```

### Option C: Optimize AVPlayer Buffering

Configure AVPlayer for faster start on cellular:

```swift
let playerItem = AVPlayerItem(url: streamURL)
playerItem.preferredForwardBufferDuration = 2.0  // Start after 2s of buffer instead of default
player.automaticallyWaitsToMinimizeStalling = false  // Start immediately, accept potential stalls
```

**Trade-off**: May cause brief stalls on very slow connections, but for music files (typically 192kbps) this is usually fine on any cellular connection.

### Option D: Preload Next Track

When the queue has a next track, start buffering it in a secondary AVPlayerItem before the current track ends:

```swift
let nextItem = AVPlayerItem(url: nextTrackURL)
nextItem.preferredForwardBufferDuration = 10.0
// Hold reference, swap to player when current track ends
```

The web side already sends `queue:nextTrackInfo` events. The bridge could forward this to native:

```js
// In bridge/playback_controller.js
this.nextTrackHandler = (e) => this.handleNextTrackInfo(e)
document.addEventListener("queue:nextTrackInfo", this.nextTrackHandler)

handleNextTrackInfo(event) {
  if (event.detail?.track) {
    this.send("preloadTrack", { track: this.buildNativeTrack(event.detail.track) })
  }
}
```

## Recommended Priority

1. **Option A** (pre-resolve S3 URL) — biggest single improvement, eliminates the redirect hop
2. **Option C** (AVPlayer buffering) — quick native-side win, no web changes needed
3. **Option B** (DNS pre-warming) — helps first-play-of-session latency
4. **Option D** (preload next track) — improves subsequent tracks, not first play

## Files to Modify

### Web Side (this repo)
| File | Change |
|------|--------|
| `app/components/track_row_component.html.erb` | Add `data-song-row-native-direct-stream-url-value` with presigned S3 URL |
| `app/javascript/controllers/song_row_controller.js` | Pass `nativeDirectStreamUrl` in event detail |
| `app/javascript/controllers/bridge/playback_controller.js` | Include `directStreamURL` in `buildNativeTrack` |
| `app/controllers/api/v1/native_controller.rb` | Add `storage_endpoint` to credentials response |

### Native Side (iOS repo)
| Component | Change |
|-----------|--------|
| PlaybackComponent handler | Prefer `directStreamURL` over `streamURL` when available |
| AVPlayer configuration | Set `preferredForwardBufferDuration` and `automaticallyWaitsToMinimizeStalling` |
| App launch | Pre-warm DNS/TLS to storage endpoint |
| PlaybackComponent handler | Handle `preloadTrack` bridge message |
