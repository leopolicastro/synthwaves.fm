import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["audio", "toggleButton", "playIcon", "pauseIcon", "label", "nowPlaying", "coverArt"]
  static values = { url: String }

  connect() {
    // Give the audio element the persistent-audio ID so lyrics/music-video controllers can bind to it
    this.audioTarget.id = "persistent-audio"

    // Toggle album art fallback when music video shows/hides
    this._onVideoShowing = () => {
      const fallback = this.element.querySelector("[data-music-video-fallback]")
      if (fallback) fallback.classList.add("hidden")
    }
    this._onVideoHidden = () => {
      const fallback = this.element.querySelector("[data-music-video-fallback]")
      if (fallback) fallback.classList.remove("hidden")
    }
    document.addEventListener("music-video:showing", this._onVideoShowing)
    document.addEventListener("music-video:hidden", this._onVideoHidden)

    // Observe the now-playing container for Turbo Stream replacements
    if (this.hasNowPlayingTarget) {
      this._observer = new MutationObserver(() => this._onNowPlayingChanged())
      this._observer.observe(this.nowPlayingTarget, { childList: true, subtree: true })
      // Dispatch initial state
      this._onNowPlayingChanged()
    }
  }

  disconnect() {
    document.removeEventListener("music-video:showing", this._onVideoShowing)
    document.removeEventListener("music-video:hidden", this._onVideoHidden)
    if (this._observer) {
      this._observer.disconnect()
      this._observer = null
    }
  }

  toggle() {
    this.audioTarget.paused ? this.play() : this.pause()
  }

  play() {
    this.audioTarget.src = this.urlValue
    this.audioTarget.play()
    this.playIconTarget.classList.add("hidden")
    this.pauseIconTarget.classList.remove("hidden")
    this.labelTarget.textContent = "Listening"
  }

  pause() {
    this.audioTarget.pause()
    this.audioTarget.src = ""
    this.pauseIconTarget.classList.add("hidden")
    this.playIconTarget.classList.remove("hidden")
    this.labelTarget.textContent = "Listen Live"
  }

  _onNowPlayingChanged() {
    if (!this.hasNowPlayingTarget) return

    const trackEl = this.nowPlayingTarget.querySelector("[data-track-id]")
    if (!trackEl) return

    const trackId = parseInt(trackEl.dataset.trackId)
    const youtubeVideoId = trackEl.dataset.youtubeVideoId || null
    const coverUrl = trackEl.dataset.coverUrl || null
    const trackStartedAt = parseFloat(trackEl.dataset.trackStartedAt) || 0

    // Update album art if we have a coverArt target
    if (this.hasCoverArtTarget && coverUrl) {
      this.coverArtTarget.src = coverUrl
      this.coverArtTarget.classList.remove("hidden")
      // Hide placeholder if present
      const placeholder = this.coverArtTarget.closest("[data-music-video-fallback]")?.querySelector("[data-placeholder]")
      if (placeholder) placeholder.classList.add("hidden")
    }

    if (trackId) {
      document.dispatchEvent(new CustomEvent("player:nowPlaying", {
        detail: { trackId, youtubeVideoId, trackStartedAt }
      }))
    }
  }
}
