import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { trackId: Number, title: String, artist: String, streamUrl: String, youtubeVideoId: String, isLive: Boolean, coverUrl: String, isPodcast: Boolean }

  play(event) {
    event.preventDefault()
    event.stopPropagation()
    const track = this.buildTrack()
    document.dispatchEvent(new CustomEvent("queue:playNow", { detail: track }))
  }

  addToQueue() {
    const track = this.buildTrack()
    document.dispatchEvent(new CustomEvent("queue:add", { detail: track }))
  }

  buildTrack() {
    const track = {
      trackId: this.trackIdValue,
      title: this.titleValue,
      artist: this.artistValue
    }

    if (this.isLiveValue) {
      track.isLive = true
    }

    if (this.coverUrlValue) {
      track.coverUrl = this.coverUrlValue
    }
    if (this.isPodcastValue) {
      track.isPodcast = true
    }

    if (this.streamUrlValue) {
      track.streamUrl = this.streamUrlValue
    } else if (this.youtubeVideoIdValue) {
      track.youtubeVideoId = this.youtubeVideoIdValue
    }

    return track
  }
}
