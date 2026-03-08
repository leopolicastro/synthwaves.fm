import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { trackId: Number, title: String, artist: String, streamUrl: String }

  play() {
    const track = {
      trackId: this.trackIdValue,
      title: this.titleValue,
      artist: this.artistValue,
      streamUrl: this.streamUrlValue
    }
    document.dispatchEvent(new CustomEvent("queue:playNow", { detail: track }))
  }

  addToQueue() {
    const track = {
      trackId: this.trackIdValue,
      title: this.titleValue,
      artist: this.artistValue,
      streamUrl: this.streamUrlValue
    }
    document.dispatchEvent(new CustomEvent("queue:add", { detail: track }))
  }
}
