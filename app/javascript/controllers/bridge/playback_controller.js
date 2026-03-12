import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "playback"

  connect() {
    super.connect()

    this.playNowHandler = (e) => this.handlePlayNow(e)
    this.addHandler = (e) => this.handleAdd(e)
    this.nowPlayingHandler = (e) => this.onNativeNowPlaying(e.detail)
    this.playbackStateHandler = (e) => this.onNativePlaybackState(e.detail)

    document.addEventListener("queue:playNow", this.playNowHandler, { capture: true })
    document.addEventListener("queue:add", this.addHandler, { capture: true })
    document.addEventListener("native:nowPlaying", this.nowPlayingHandler)
    document.addEventListener("native:playbackState", this.playbackStateHandler)
  }

  disconnect() {
    super.disconnect()

    document.removeEventListener("queue:playNow", this.playNowHandler, { capture: true })
    document.removeEventListener("queue:add", this.addHandler, { capture: true })
    document.removeEventListener("native:nowPlaying", this.nowPlayingHandler)
    document.removeEventListener("native:playbackState", this.playbackStateHandler)
  }

  handlePlayNow(event) {
    event.stopImmediatePropagation()
    this.send("playTrack", { track: this.buildNativeTrack(event.detail) })
  }

  handleAdd(event) {
    event.stopImmediatePropagation()
    this.send("queueAdd", { track: this.buildNativeTrack(event.detail) })
  }

  buildNativeTrack(detail) {
    return {
      id: detail.trackId,
      title: detail.title,
      artist: detail.artist,
      albumTitle: detail.albumTitle || "",
      streamURL: detail.nativeStreamUrl || detail.streamUrl || "",
      coverArtURL: detail.nativeCoverArtUrl || detail.coverUrl || "",
      duration: detail.duration || 0,
      isLive: detail.isLive || false,
      isPodcast: detail.isPodcast || false,
      youtubeVideoId: detail.youtubeVideoId || ""
    }
  }

  onNativeNowPlaying({ trackId }) {
    document.querySelectorAll("[data-song-row-track-id-value]").forEach((el) => {
      const isPlaying = el.dataset.songRowTrackIdValue === String(trackId)
      el.classList.toggle("now-playing", isPlaying)
    })
  }

  onNativePlaybackState({ state }) {
    document.dispatchEvent(new CustomEvent("player:nativeState", { detail: { state } }))
  }
}
