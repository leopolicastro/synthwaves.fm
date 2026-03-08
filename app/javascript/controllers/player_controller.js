import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["progress", "title", "artist", "artwork", "playIcon", "pauseIcon", "currentTime", "duration", "volume", "progressBar", "liveIndicator", "prevButton", "nextButton", "repeatOff", "repeatAll", "repeatOne", "shuffleIcon"]
  static values = { playHistoryUrl: String }

  connect() {
    // Append <audio> to <html> (outside <body>) so Turbo's body
    // replacement never detaches it — same pattern as youtube_player_controller.
    this.audio = this._ensureAudio()

    // Only initialize state and audio element listeners once
    if (!this.audio._playerInitialized) {
      this.audio._playerInitialized = true
      this.youtubeActive = false
      this.youtubePlaying = false
      this.currentIsLive = false
      this.repeatMode = "off"
      this.shuffleEnabled = false
      this.youtubeCurrentTime = 0
      this.youtubeDuration = 0

      this.audio.addEventListener("timeupdate", () => this.onTimeUpdate())
      this.audio.addEventListener("ended", () => this.onEnded())
      this.audio.addEventListener("loadedmetadata", () => this.onLoadedMetadata())
      this.audio.addEventListener("play", () => {
        this.updatePlayPauseIcon()
        this.startPositionSave()
      })
      this.audio.addEventListener("pause", () => {
        this.updatePlayPauseIcon()
        this.stopPositionSave()
      })
    }

    this.playTrackHandler = (e) => this.playTrack(e.detail)
    this.playYouTubeHandler = (e) => this.playYouTube(e.detail)
    this.youtubeStateHandler = (e) => this.onYouTubeState(e.detail)
    this.youtubeTimeHandler = (e) => this.onYouTubeTime(e.detail)
    this.youtubeStoppedHandler = () => this.onYouTubeStopped()
    this.repeatChangedHandler = (e) => this.onRepeatChanged(e.detail)
    this.shuffleChangedHandler = (e) => this.onShuffleChanged(e.detail)

    document.addEventListener("player:play", this.playTrackHandler)
    document.addEventListener("player:playYouTube", this.playYouTubeHandler)
    document.addEventListener("youtube:stateChange", this.youtubeStateHandler)
    document.addEventListener("youtube:timeUpdate", this.youtubeTimeHandler)
    document.addEventListener("youtube:stopped", this.youtubeStoppedHandler)
    document.addEventListener("queue:repeatChanged", this.repeatChangedHandler)
    document.addEventListener("queue:shuffleChanged", this.shuffleChangedHandler)

    if ("mediaSession" in navigator) {
      navigator.mediaSession.setActionHandler("play", () => this.toggle())
      navigator.mediaSession.setActionHandler("pause", () => this.toggle())
      navigator.mediaSession.setActionHandler("previoustrack", () => this.previous())
      navigator.mediaSession.setActionHandler("nexttrack", () => this.next())
    }

    this.restoreSession()
  }

  disconnect() {
    this.stopPositionSave()
    document.removeEventListener("player:play", this.playTrackHandler)
    document.removeEventListener("player:playYouTube", this.playYouTubeHandler)
    document.removeEventListener("youtube:stateChange", this.youtubeStateHandler)
    document.removeEventListener("youtube:timeUpdate", this.youtubeTimeHandler)
    document.removeEventListener("youtube:stopped", this.youtubeStoppedHandler)
    document.removeEventListener("queue:repeatChanged", this.repeatChangedHandler)
    document.removeEventListener("queue:shuffleChanged", this.shuffleChangedHandler)
  }

  // Persistent audio element — lives on <html> so Turbo never detaches it

  _ensureAudio() {
    let audio = document.getElementById("persistent-audio")
    if (!audio) {
      audio = document.createElement("audio")
      audio.id = "persistent-audio"
      audio.preload = "auto"
      document.documentElement.appendChild(audio)
    }
    return audio
  }

  // Session restore

  restoreSession() {
    const savedVolume = localStorage.getItem("playerVolume")
    if (savedVolume !== null) {
      this.audio.volume = parseFloat(savedVolume)
      this.volumeTarget.value = savedVolume
    }

    this.repeatMode = localStorage.getItem("playerRepeatMode") || "off"
    this.updateRepeatIcon()

    this.shuffleEnabled = localStorage.getItem("playerShuffle") === "true"
    this.updateShuffleIcon()

    // Don't interrupt active playback on reconnect
    if (!this.audio.paused || this.youtubeActive) return

    const savedTrack = localStorage.getItem("playerCurrentTrack")
    if (!savedTrack) return

    try {
      const track = JSON.parse(savedTrack)
      this.currentTrackId = track.trackId
      this.titleTarget.textContent = track.title || "Not playing"
      this.artistTarget.textContent = track.artist || ""
      this.currentIsLive = track.isLive || false

      if (this.currentIsLive) {
        this.showLiveMode()
      } else {
        this.showNormalMode()
      }

      const savedTime = parseFloat(localStorage.getItem("playerCurrentTime") || "0")

      if (track.youtubeVideoId) {
        this.youtubeActive = true
        this._currentYouTubeVideoId = track.youtubeVideoId
        if (savedTime > 0 && !track.isLive) {
          this.currentTimeTarget.textContent = this.formatTime(savedTime)
        }
      } else if (track.streamUrl) {
        this.audio.src = track.streamUrl
        if (savedTime > 0) {
          this.audio.addEventListener("loadedmetadata", () => {
            this.audio.currentTime = savedTime
          }, { once: true })
          this.currentTimeTarget.textContent = this.formatTime(savedTime)
        }
      }

      this.dispatchNowPlaying(track.trackId)

      if ("mediaSession" in navigator && track.title) {
        navigator.mediaSession.metadata = new MediaMetadata({
          title: track.title,
          artist: track.isLive ? "Live" : (track.artist || "")
        })
      }
    } catch (e) {
      // Ignore invalid saved data
    }
  }

  // Position persistence

  savePosition() {
    if (this.currentIsLive) return

    let currentTime = 0
    if (this.youtubeActive) {
      currentTime = this.youtubeCurrentTime || 0
    } else {
      currentTime = this.audio.currentTime || 0
    }

    localStorage.setItem("playerCurrentTime", currentTime.toString())
  }

  startPositionSave() {
    this.stopPositionSave()
    this._positionInterval = setInterval(() => this.savePosition(), 5000)
  }

  stopPositionSave() {
    if (this._positionInterval) {
      clearInterval(this._positionInterval)
      this._positionInterval = null
    }
  }

  saveCurrentTrack(track) {
    localStorage.setItem("playerCurrentTrack", JSON.stringify(track))
    localStorage.setItem("playerCurrentTime", "0")
  }

  // Playback

  playTrack({ trackId, title, artist, streamUrl }) {
    if (this.youtubeActive) {
      document.dispatchEvent(new CustomEvent("youtube:stop"))
      this.youtubeActive = false
      this.youtubePlaying = false
    }

    this.currentIsLive = false
    this.currentTrackId = trackId
    this._currentYouTubeVideoId = null
    this.titleTarget.textContent = title
    this.artistTarget.textContent = artist
    this.showNormalMode()

    this.audio.src = streamUrl
    this.audio.play()

    this.saveCurrentTrack({ trackId, title, artist, streamUrl })
    this.startPositionSave()
    this.dispatchNowPlaying(trackId)

    if ("mediaSession" in navigator) {
      navigator.mediaSession.metadata = new MediaMetadata({ title, artist })
    }

    this.recordPlay(trackId)
  }

  playYouTube({ trackId, title, artist, youtubeVideoId, isLive }) {
    this.audio.pause()
    this.audio.removeAttribute("src")

    this.youtubeActive = true
    this.currentIsLive = isLive || false
    this.currentTrackId = trackId
    this._currentYouTubeVideoId = youtubeVideoId
    this.youtubeCurrentTime = 0
    this.youtubeDuration = 0
    this.titleTarget.textContent = title
    this.artistTarget.textContent = artist

    if (this.currentIsLive) {
      this.showLiveMode()
    } else {
      this.showNormalMode()
    }

    document.dispatchEvent(new CustomEvent("youtube:play", {
      detail: { videoId: youtubeVideoId, isLive: this.currentIsLive }
    }))

    this.saveCurrentTrack({ trackId, title, artist, youtubeVideoId, isLive: isLive || false })
    this.startPositionSave()
    this.dispatchNowPlaying(trackId)

    if ("mediaSession" in navigator) {
      navigator.mediaSession.metadata = new MediaMetadata({
        title,
        artist: isLive ? "Live" : artist
      })
    }

    if (!isLive && trackId) {
      this.recordPlay(trackId)
    }
  }

  toggle() {
    if (this.youtubeActive) {
      document.dispatchEvent(new CustomEvent("youtube:toggle"))
    } else {
      if (this.audio.paused) {
        this.audio.play()
      } else {
        this.audio.pause()
      }
    }
  }

  previous() {
    document.dispatchEvent(new CustomEvent("queue:previous"))
  }

  next() {
    document.dispatchEvent(new CustomEvent("queue:next"))
  }

  seek(event) {
    if (this.youtubeActive) return
    const rect = event.currentTarget.getBoundingClientRect()
    const percent = (event.clientX - rect.left) / rect.width
    this.audio.currentTime = percent * this.audio.duration
  }

  setVolume() {
    this.audio.volume = this.volumeTarget.value
    localStorage.setItem("playerVolume", this.volumeTarget.value)
  }

  // Repeat

  cycleRepeat() {
    document.dispatchEvent(new CustomEvent("queue:cycleRepeat"))
  }

  onRepeatChanged({ mode }) {
    this.repeatMode = mode
    this.updateRepeatIcon()
  }

  updateRepeatIcon() {
    if (this.hasRepeatOffTarget) {
      this.repeatOffTarget.classList.toggle("hidden", this.repeatMode !== "off")
    }
    if (this.hasRepeatAllTarget) {
      this.repeatAllTarget.classList.toggle("hidden", this.repeatMode !== "all")
    }
    if (this.hasRepeatOneTarget) {
      this.repeatOneTarget.classList.toggle("hidden", this.repeatMode !== "one")
    }
  }

  // Shuffle

  toggleShuffle() {
    document.dispatchEvent(new CustomEvent("queue:toggleShuffle"))
  }

  onShuffleChanged({ enabled }) {
    this.shuffleEnabled = enabled
    this.updateShuffleIcon()
  }

  updateShuffleIcon() {
    if (this.hasShuffleIconTarget) {
      if (this.shuffleEnabled) {
        this.shuffleIconTarget.classList.remove("text-gray-500")
        this.shuffleIconTarget.classList.add("text-neon-cyan")
      } else {
        this.shuffleIconTarget.classList.remove("text-neon-cyan")
        this.shuffleIconTarget.classList.add("text-gray-500")
      }
    }
  }

  // Queue panel

  toggleQueue() {
    document.dispatchEvent(new CustomEvent("queue-panel:toggle"))
  }

  // Now playing

  dispatchNowPlaying(trackId) {
    document.dispatchEvent(new CustomEvent("player:nowPlaying", {
      detail: { trackId }
    }))
  }

  // Local audio events

  onTimeUpdate() {
    if (this.youtubeActive) return
    if (this.audio.duration) {
      const percent = (this.audio.currentTime / this.audio.duration) * 100
      this.progressTarget.style.width = `${percent}%`
      this.currentTimeTarget.textContent = this.formatTime(this.audio.currentTime)
    }
  }

  onLoadedMetadata() {
    if (this.youtubeActive) return
    this.durationTarget.textContent = this.formatTime(this.audio.duration)
  }

  onEnded() {
    if (this.repeatMode === "one") {
      this.audio.currentTime = 0
      this.audio.play()
      return
    }
    document.dispatchEvent(new CustomEvent("queue:next"))
  }

  // YouTube events

  onYouTubeState({ state }) {
    if (!this.youtubeActive) return

    if (state === "playing") {
      this.youtubePlaying = true
      this.playIconTarget.classList.add("hidden")
      this.pauseIconTarget.classList.remove("hidden")
      this.startPositionSave()
    } else if (state === "paused") {
      this.youtubePlaying = false
      this.playIconTarget.classList.remove("hidden")
      this.pauseIconTarget.classList.add("hidden")
      this.stopPositionSave()
    } else if (state === "ended") {
      this.youtubePlaying = false
      this.stopPositionSave()
      if (this.repeatMode === "one" && this._currentYouTubeVideoId) {
        document.dispatchEvent(new CustomEvent("youtube:play", {
          detail: { videoId: this._currentYouTubeVideoId, isLive: false }
        }))
        return
      }
      document.dispatchEvent(new CustomEvent("queue:next"))
    }
  }

  onYouTubeTime({ currentTime, duration }) {
    if (!this.youtubeActive || this.currentIsLive) return

    this.youtubeCurrentTime = currentTime
    this.youtubeDuration = duration

    if (duration > 0) {
      const percent = (currentTime / duration) * 100
      this.progressTarget.style.width = `${percent}%`
      this.currentTimeTarget.textContent = this.formatTime(currentTime)
      this.durationTarget.textContent = this.formatTime(duration)
    }
  }

  onYouTubeStopped() {
    this.youtubeActive = false
    this.youtubePlaying = false
    this.stopPositionSave()
    this.showNormalMode()
    this.updatePlayPauseIcon()
  }

  // UI modes

  showLiveMode() {
    if (this.hasProgressBarTarget) {
      this.progressBarTarget.classList.add("hidden")
    }
    if (this.hasLiveIndicatorTarget) {
      this.liveIndicatorTarget.classList.remove("hidden")
    }
    this.currentTimeTarget.textContent = ""
    this.durationTarget.textContent = ""
    this.progressTarget.style.width = "0%"
  }

  showNormalMode() {
    if (this.hasProgressBarTarget) {
      this.progressBarTarget.classList.remove("hidden")
    }
    if (this.hasLiveIndicatorTarget) {
      this.liveIndicatorTarget.classList.add("hidden")
    }
  }

  updatePlayPauseIcon() {
    if (this.youtubeActive) return

    if (this.audio.paused) {
      this.playIconTarget.classList.remove("hidden")
      this.pauseIconTarget.classList.add("hidden")
    } else {
      this.playIconTarget.classList.add("hidden")
      this.pauseIconTarget.classList.remove("hidden")
    }
  }

  recordPlay(trackId) {
    if (this.playHistoryUrlValue && trackId) {
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
