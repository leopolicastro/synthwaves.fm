import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay", "albumArt", "title", "artist", "progress", "currentTime", "duration", "playIcon", "pauseIcon", "lyrics"]

  connect() {
    this._visible = false
    this._nowPlayingHandler = (e) => this._onNowPlaying(e.detail)
    this._toggleHandler = () => this.toggle()
    this._closeHandler = () => this.close()

    document.addEventListener("player:nowPlaying", this._nowPlayingHandler)
    document.addEventListener("fullscreen-now-playing:toggle", this._toggleHandler)
    document.addEventListener("fullscreen-now-playing:close", this._closeHandler)

    this._audio = document.getElementById("persistent-audio")
    if (this._audio) {
      this._onTimeUpdate = () => this._updateProgress()
      this._onPlay = () => this._updatePlayPause(false)
      this._onPause = () => this._updatePlayPause(true)
      this._audio.addEventListener("timeupdate", this._onTimeUpdate)
      this._audio.addEventListener("play", this._onPlay)
      this._audio.addEventListener("pause", this._onPause)
    }
  }

  disconnect() {
    document.removeEventListener("player:nowPlaying", this._nowPlayingHandler)
    document.removeEventListener("fullscreen-now-playing:toggle", this._toggleHandler)
    document.removeEventListener("fullscreen-now-playing:close", this._closeHandler)

    if (this._audio) {
      this._audio.removeEventListener("timeupdate", this._onTimeUpdate)
      this._audio.removeEventListener("play", this._onPlay)
      this._audio.removeEventListener("pause", this._onPause)
    }
  }

  toggle() {
    this._visible ? this.close() : this.open()
  }

  open() {
    if (!this.hasOverlayTarget) return
    this._visible = true
    this.overlayTarget.classList.remove("hidden")
    requestAnimationFrame(() => {
      this.overlayTarget.classList.add("opacity-100")
      this.overlayTarget.classList.remove("opacity-0")
    })
  }

  close() {
    if (!this.hasOverlayTarget || !this._visible) return
    this._visible = false
    this.overlayTarget.classList.add("opacity-0")
    this.overlayTarget.classList.remove("opacity-100")
    setTimeout(() => this.overlayTarget.classList.add("hidden"), 300)
  }

  togglePlayback() {
    document.dispatchEvent(new CustomEvent("player:toggle"))
    // Also dispatch to the player controller's toggle
    const audio = document.getElementById("persistent-audio")
    if (audio) {
      if (audio.paused) audio.play(); else audio.pause()
    }
  }

  previous() {
    document.dispatchEvent(new CustomEvent("queue:previous"))
  }

  next() {
    document.dispatchEvent(new CustomEvent("queue:next"))
  }

  seek(event) {
    if (!this._audio || !this._audio.duration) return
    const rect = event.currentTarget.getBoundingClientRect()
    const percent = (event.clientX - rect.left) / rect.width
    this._audio.currentTime = percent * this._audio.duration
  }

  _onNowPlaying({ title, artist, coverUrl }) {
    if (this.hasTitleTarget) this.titleTarget.textContent = title || ""
    if (this.hasArtistTarget) this.artistTarget.textContent = artist || ""
    if (this.hasAlbumArtTarget) {
      if (coverUrl) {
        this.albumArtTarget.innerHTML = `<img src="${coverUrl}" class="w-full h-full object-cover rounded-lg" alt="">`
      } else {
        this.albumArtTarget.innerHTML = '<div class="w-full h-full bg-gray-700 rounded-lg flex items-center justify-center"><svg class="w-16 h-16 text-gray-500" fill="currentColor" viewBox="0 0 20 20"><path d="M18 3a1 1 0 00-1.196-.98l-10 2A1 1 0 006 5v9.114A4.369 4.369 0 005 14c-1.657 0-3 .895-3 2s1.343 2 3 2 3-.895 3-2V7.82l8-1.6v5.894A4.37 4.37 0 0015 12c-1.657 0-3 .895-3 2s1.343 2 3 2 3-.895 3-2V3z"/></svg></div>'
      }
    }
  }

  _updateProgress() {
    if (!this._audio || !this._audio.duration || !this._visible) return
    const percent = (this._audio.currentTime / this._audio.duration) * 100
    if (this.hasProgressTarget) this.progressTarget.style.width = `${percent}%`
    if (this.hasCurrentTimeTarget) this.currentTimeTarget.textContent = this._formatTime(this._audio.currentTime)
    if (this.hasDurationTarget) this.durationTarget.textContent = this._formatTime(this._audio.duration)
  }

  _updatePlayPause(paused) {
    if (this.hasPlayIconTarget) this.playIconTarget.classList.toggle("hidden", !paused)
    if (this.hasPauseIconTarget) this.pauseIconTarget.classList.toggle("hidden", paused)
  }

  _formatTime(seconds) {
    if (!seconds || isNaN(seconds) || !isFinite(seconds)) return "0:00"
    const mins = Math.floor(seconds / 60)
    const secs = Math.floor(seconds % 60)
    return `${mins}:${secs.toString().padStart(2, "0")}`
  }
}
