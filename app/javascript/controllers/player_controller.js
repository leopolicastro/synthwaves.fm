import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["audio", "progress", "title", "artist", "artwork", "playIcon", "pauseIcon", "currentTime", "duration", "volume"]
  static values = { playHistoryUrl: String }

  connect() {
    this.audio = this.audioTarget

    this.audio.addEventListener("timeupdate", () => this.onTimeUpdate())
    this.audio.addEventListener("ended", () => this.onEnded())
    this.audio.addEventListener("loadedmetadata", () => this.onLoadedMetadata())
    this.audio.addEventListener("play", () => this.updatePlayPauseIcon())
    this.audio.addEventListener("pause", () => this.updatePlayPauseIcon())

    this.playTrackHandler = (e) => this.playTrack(e.detail)
    document.addEventListener("player:play", this.playTrackHandler)

    if ("mediaSession" in navigator) {
      navigator.mediaSession.setActionHandler("play", () => this.audio.play())
      navigator.mediaSession.setActionHandler("pause", () => this.audio.pause())
      navigator.mediaSession.setActionHandler("previoustrack", () => this.previous())
      navigator.mediaSession.setActionHandler("nexttrack", () => this.next())
    }
  }

  disconnect() {
    document.removeEventListener("player:play", this.playTrackHandler)
  }

  playTrack({ trackId, title, artist, streamUrl }) {
    this.currentTrackId = trackId
    this.titleTarget.textContent = title
    this.artistTarget.textContent = artist

    this.audio.src = streamUrl
    this.audio.play()

    if ("mediaSession" in navigator) {
      navigator.mediaSession.metadata = new MediaMetadata({ title, artist })
    }

    this.recordPlay(trackId)
  }

  toggle() {
    if (this.audio.paused) {
      this.audio.play()
    } else {
      this.audio.pause()
    }
  }

  previous() {
    document.dispatchEvent(new CustomEvent("queue:previous"))
  }

  next() {
    document.dispatchEvent(new CustomEvent("queue:next"))
  }

  seek(event) {
    const rect = event.currentTarget.getBoundingClientRect()
    const percent = (event.clientX - rect.left) / rect.width
    this.audio.currentTime = percent * this.audio.duration
  }

  setVolume() {
    this.audio.volume = this.volumeTarget.value
  }

  onTimeUpdate() {
    if (this.audio.duration) {
      const percent = (this.audio.currentTime / this.audio.duration) * 100
      this.progressTarget.style.width = `${percent}%`
      this.currentTimeTarget.textContent = this.formatTime(this.audio.currentTime)
    }
  }

  onLoadedMetadata() {
    this.durationTarget.textContent = this.formatTime(this.audio.duration)
  }

  onEnded() {
    document.dispatchEvent(new CustomEvent("queue:next"))
  }

  updatePlayPauseIcon() {
    if (this.audio.paused) {
      this.playIconTarget.classList.remove("hidden")
      this.pauseIconTarget.classList.add("hidden")
    } else {
      this.playIconTarget.classList.add("hidden")
      this.pauseIconTarget.classList.remove("hidden")
    }
  }

  recordPlay(trackId) {
    if (this.playHistoryUrlValue) {
      fetch(this.playHistoryUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({ track_id: trackId })
      })
    }
  }

  formatTime(seconds) {
    if (!seconds || isNaN(seconds)) return "0:00"
    const mins = Math.floor(seconds / 60)
    const secs = Math.floor(seconds % 60)
    return `${mins}:${secs.toString().padStart(2, "0")}`
  }
}
