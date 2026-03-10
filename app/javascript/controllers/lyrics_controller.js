import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]

  connect() {
    this._currentTrackId = null
    this._nowPlayingHandler = (e) => this._onNowPlaying(e.detail)
    document.addEventListener("player:nowPlaying", this._nowPlayingHandler)
  }

  disconnect() {
    document.removeEventListener("player:nowPlaying", this._nowPlayingHandler)
  }

  _onNowPlaying({ trackId }) {
    if (!trackId || trackId === this._currentTrackId) return
    this._currentTrackId = trackId
    this._fetchLyrics(trackId)
  }

  async _fetchLyrics(trackId) {
    if (!this.hasContentTarget) return
    this.contentTarget.textContent = ""

    try {
      const response = await fetch(`/tracks/${trackId}/lyrics.json`)
      if (!response.ok) return
      const data = await response.json()
      if (data.lyrics) {
        this.contentTarget.textContent = data.lyrics
      }
    } catch (e) {
      // Silently fail
    }
  }
}
