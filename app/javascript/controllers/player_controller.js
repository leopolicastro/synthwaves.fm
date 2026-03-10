import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["progress", "title", "artist", "artwork", "playIcon", "pauseIcon", "currentTime", "duration", "volume", "progressBar", "liveIndicator", "prevButton", "nextButton", "repeatOff", "repeatAll", "repeatOne", "shuffleIcon", "speedControl", "speedDisplay"]
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
      this.audio.addEventListener("error", (e) => {
        console.warn("Audio error:", this.audio.error?.message, this.audio.error?.code)
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
    this.nextTrackInfoHandler = (e) => this._onNextTrackInfo(e.detail)
    this.seekForwardHandler = () => this.seekForward()
    this.seekBackwardHandler = () => this.seekBackward()
    this.volumeUpHandler = () => this.volumeUp()
    this.volumeDownHandler = () => this.volumeDown()
    this.toggleMuteHandler = () => this.toggleMute()

    document.addEventListener("player:play", this.playTrackHandler)
    document.addEventListener("player:playYouTube", this.playYouTubeHandler)
    document.addEventListener("youtube:stateChange", this.youtubeStateHandler)
    document.addEventListener("youtube:timeUpdate", this.youtubeTimeHandler)
    document.addEventListener("youtube:stopped", this.youtubeStoppedHandler)
    this.castStateHandler = (e) => this.onCastStateChanged(e.detail)
    this.airplayStateHandler = (e) => this.onAirplayStateChanged(e.detail)
    document.addEventListener("queue:repeatChanged", this.repeatChangedHandler)
    document.addEventListener("queue:shuffleChanged", this.shuffleChangedHandler)
    document.addEventListener("cast:stateChanged", this.castStateHandler)
    document.addEventListener("airplay:stateChanged", this.airplayStateHandler)
    document.addEventListener("queue:nextTrackInfo", this.nextTrackInfoHandler)
    document.addEventListener("player:seekForward", this.seekForwardHandler)
    document.addEventListener("player:seekBackward", this.seekBackwardHandler)
    document.addEventListener("player:volumeUp", this.volumeUpHandler)
    document.addEventListener("player:volumeDown", this.volumeDownHandler)
    document.addEventListener("player:toggleMute", this.toggleMuteHandler)

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
    document.removeEventListener("cast:stateChanged", this.castStateHandler)
    document.removeEventListener("airplay:stateChanged", this.airplayStateHandler)
    document.removeEventListener("queue:nextTrackInfo", this.nextTrackInfoHandler)
    document.removeEventListener("player:seekForward", this.seekForwardHandler)
    document.removeEventListener("player:seekBackward", this.seekBackwardHandler)
    document.removeEventListener("player:volumeUp", this.volumeUpHandler)
    document.removeEventListener("player:volumeDown", this.volumeDownHandler)
    document.removeEventListener("player:toggleMute", this.toggleMuteHandler)
  }

  // Persistent audio element — lives on <html> so Turbo never detaches it

  _ensureAudio() {
    let audio = document.getElementById("persistent-audio")
    if (!audio) {
      audio = document.createElement("audio")
      audio.id = "persistent-audio"
      audio.preload = "auto"
      audio.setAttribute("x-webkit-airplay", "allow")
      document.documentElement.appendChild(audio)
    }
    return audio
  }

  _ensurePreloadAudio() {
    let audio = document.getElementById("persistent-audio-preload")
    if (!audio) {
      audio = document.createElement("audio")
      audio.id = "persistent-audio-preload"
      audio.preload = "auto"
      document.documentElement.appendChild(audio)
    }
    return audio
  }

  get crossfadeDuration() {
    return parseInt(localStorage.getItem("crossfadeDuration") || "0")
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
      this.currentCoverUrl = track.coverUrl || null
      this.titleTarget.textContent = track.title || "Not playing"
      this.artistTarget.textContent = track.artist || ""
      this.currentIsLive = track.isLive || false
      this._updateArtwork(track.coverUrl)

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

      this.dispatchNowPlaying({ trackId: track.trackId, title: track.title, artist: track.artist, coverUrl: track.coverUrl })

      if ("mediaSession" in navigator && track.title) {
        const metadata = { title: track.title, artist: track.isLive ? "Live" : (track.artist || "") }
        if (track.coverUrl) metadata.artwork = [{ src: track.coverUrl }]
        navigator.mediaSession.metadata = new MediaMetadata(metadata)
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

  // Cast state

  onCastStateChanged({ active }) {
    this.castActive = active
    if (!active) {
      // Resume local playback when cast disconnects
    }
  }

  onAirplayStateChanged({ active }) {
    this.airplayActive = active
  }

  // Playback

  playTrack({ trackId, title, artist, streamUrl, isLive, coverUrl, isPodcast }) {
    if (this.youtubeActive) {
      document.dispatchEvent(new CustomEvent("youtube:stop"))
      this.youtubeActive = false
      this.youtubePlaying = false
    }

    this.currentIsLive = isLive || false
    this.currentIsPodcast = isPodcast || false
    this.currentTrackId = trackId
    this.currentCoverUrl = coverUrl || null
    this._currentYouTubeVideoId = null
    this.titleTarget.textContent = title
    this.artistTarget.textContent = isLive ? "Live" : artist
    this._updateArtwork(coverUrl)

    if (this.currentIsLive) {
      this.showLiveMode()
    } else {
      this.showNormalMode()
    }

    this.saveCurrentTrack({ trackId, title, artist, streamUrl, isLive: isLive || false, coverUrl: coverUrl || null, isPodcast: isPodcast || false })
    this.dispatchNowPlaying({ trackId, title, artist, coverUrl })
    this._applyPlaybackRate()

    // If casting, send to cast device instead of local audio
    if (this.castActive) {
      document.dispatchEvent(new CustomEvent("cast:loadMedia", {
        detail: { streamUrl, title, artist }
      }))
      document.dispatchEvent(new CustomEvent("player:sourceChanged", {
        detail: { streamUrl }
      }))
    } else {
      // Resolve the redirect to get the direct URL (e.g. presigned S3 URL)
      // so AirPlay sends the resolved URL to the Apple TV, not the app URL
      this._resolveAndPlay(streamUrl)
    }

    this.startPositionSave()

    if ("mediaSession" in navigator) {
      const metadata = { title, artist: isLive ? "Live" : artist }
      if (coverUrl) metadata.artwork = [{ src: coverUrl }]
      navigator.mediaSession.metadata = new MediaMetadata(metadata)
    }

    if (!isLive) {
      this.recordPlay(trackId)
    }
  }

  playYouTube({ trackId, title, artist, youtubeVideoId, isLive, coverUrl }) {
    this.audio.pause()
    this.audio.removeAttribute("src")

    this.youtubeActive = true
    this.currentIsLive = isLive || false
    this.currentTrackId = trackId
    this.currentCoverUrl = coverUrl || null
    this._currentYouTubeVideoId = youtubeVideoId
    this.youtubeCurrentTime = 0
    this.youtubeDuration = 0
    this.titleTarget.textContent = title
    this.artistTarget.textContent = artist
    this._updateArtwork(coverUrl)

    if (this.currentIsLive) {
      this.showLiveMode()
    } else {
      this.showNormalMode()
    }

    document.dispatchEvent(new CustomEvent("youtube:play", {
      detail: { videoId: youtubeVideoId, isLive: this.currentIsLive }
    }))

    this.saveCurrentTrack({ trackId, title, artist, youtubeVideoId, isLive: isLive || false, coverUrl: coverUrl || null })
    this.startPositionSave()
    this.dispatchNowPlaying({ trackId, title, artist, coverUrl })

    if ("mediaSession" in navigator) {
      const metadata = { title, artist: isLive ? "Live" : artist }
      if (coverUrl) metadata.artwork = [{ src: coverUrl }]
      navigator.mediaSession.metadata = new MediaMetadata(metadata)
    }

    if (!isLive && trackId) {
      this.recordPlay(trackId)
    }
  }

  toggle() {
    if (this.castActive) {
      document.dispatchEvent(new CustomEvent("cast:toggle"))
    } else if (this.youtubeActive) {
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

  seekForward() {
    if (this.youtubeActive || this.currentIsLive) return
    this.audio.currentTime = Math.min(this.audio.currentTime + 5, this.audio.duration || Infinity)
  }

  seekBackward() {
    if (this.youtubeActive || this.currentIsLive) return
    this.audio.currentTime = Math.max(this.audio.currentTime - 5, 0)
  }

  setVolume() {
    this.audio.volume = this.volumeTarget.value
    localStorage.setItem("playerVolume", this.volumeTarget.value)
  }

  volumeUp() {
    const newVol = Math.min(this.audio.volume + 0.05, 1)
    this.audio.volume = newVol
    this.volumeTarget.value = newVol
    localStorage.setItem("playerVolume", newVol.toString())
  }

  volumeDown() {
    const newVol = Math.max(this.audio.volume - 0.05, 0)
    this.audio.volume = newVol
    this.volumeTarget.value = newVol
    localStorage.setItem("playerVolume", newVol.toString())
  }

  toggleMute() {
    if (this.audio.muted) {
      this.audio.muted = false
    } else {
      this.audio.muted = true
    }
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

  // Visualizer panel

  toggleVisualizer() {
    document.dispatchEvent(new CustomEvent("visualizer-panel:toggle"))
  }

  toggleFullscreen() {
    document.dispatchEvent(new CustomEvent("fullscreen-now-playing:toggle"))
  }

  // Now playing

  dispatchNowPlaying({ trackId, title, artist, coverUrl }) {
    document.dispatchEvent(new CustomEvent("player:nowPlaying", {
      detail: { trackId, title, artist, coverUrl }
    }))
  }

  _updateArtwork(coverUrl) {
    if (!this.hasArtworkTarget) return
    if (coverUrl) {
      this.artworkTarget.innerHTML = `<img src="${coverUrl}" class="w-10 h-10 rounded object-cover" alt="">`
    } else {
      this.artworkTarget.innerHTML = '<svg class="w-5 h-5 text-gray-400" fill="currentColor" viewBox="0 0 20 20"><path d="M18 3a1 1 0 00-1.196-.98l-10 2A1 1 0 006 5v9.114A4.369 4.369 0 005 14c-1.657 0-3 .895-3 2s1.343 2 3 2 3-.895 3-2V7.82l8-1.6v5.894A4.37 4.37 0 0015 12c-1.657 0-3 .895-3 2s1.343 2 3 2 3-.895 3-2V3z"/></svg>'
    }
  }

  // Local audio events

  onTimeUpdate() {
    if (this.youtubeActive || this.currentIsLive) return
    if (this.audio.duration) {
      const percent = (this.audio.currentTime / this.audio.duration) * 100
      this.progressTarget.style.width = `${percent}%`
      this.currentTimeTarget.textContent = this.formatTime(this.audio.currentTime)

      // Crossfade trigger: start crossfade when remaining time <= crossfade duration
      const remaining = this.audio.duration - this.audio.currentTime
      const cfDuration = this.crossfadeDuration
      if (cfDuration > 0 && remaining <= cfDuration && remaining > 0.5 && !this._crossfading) {
        this._startCrossfade()
      }
    }
  }

  onLoadedMetadata() {
    if (this.youtubeActive || this.currentIsLive) return
    if (!isFinite(this.audio.duration)) {
      this.currentIsLive = true
      this.showLiveMode()
      return
    }
    this.durationTarget.textContent = this.formatTime(this.audio.duration)
  }

  onEnded() {
    if (this._crossfading) return // Crossfade already handling transition
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

  async _resolveAndPlay(streamUrl) {
    try {
      const response = await fetch(streamUrl, { method: "HEAD" })
      const resolvedUrl = response.url
      this.audio.src = resolvedUrl
      this.audio.play()
      document.dispatchEvent(new CustomEvent("player:sourceChanged", {
        detail: { streamUrl: resolvedUrl }
      }))
    } catch (e) {
      // Fall back to original URL if resolve fails
      this.audio.src = streamUrl
      this.audio.play()
      document.dispatchEvent(new CustomEvent("player:sourceChanged", {
        detail: { streamUrl }
      }))
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

  // Preload and crossfade

  _onNextTrackInfo({ track }) {
    if (!track || track.youtubeVideoId) {
      this._pendingPreload = null
      return
    }
    this._pendingPreload = track
    // Preload next track for gapless/crossfade
    const preload = this._ensurePreloadAudio()
    if (preload.src !== track.streamUrl) {
      preload.src = track.streamUrl
      preload.load()
    }
  }

  _startCrossfade() {
    if (!this._pendingPreload || this._pendingPreload.youtubeVideoId) return
    if (this.repeatMode === "one") return

    this._crossfading = true
    const preload = this._ensurePreloadAudio()
    const cfDuration = this.crossfadeDuration * 1000 // ms
    const oldAudio = this.audio
    const targetVolume = oldAudio.volume

    preload.volume = 0
    preload.play()

    const startTime = performance.now()
    const fade = () => {
      const elapsed = performance.now() - startTime
      const progress = Math.min(elapsed / cfDuration, 1)
      oldAudio.volume = targetVolume * (1 - progress)
      preload.volume = targetVolume * progress
      if (progress < 1) {
        requestAnimationFrame(fade)
      } else {
        // Swap complete
        oldAudio.pause()
        oldAudio.removeAttribute("src")
        oldAudio.volume = targetVolume

        // Swap IDs so this.audio points to the new playing element
        oldAudio.id = "persistent-audio-preload"
        preload.id = "persistent-audio"
        this.audio = preload

        // Re-attach listeners for the new audio element
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

        this._crossfading = false

        document.dispatchEvent(new CustomEvent("player:sourceChanged", {
          detail: { streamUrl: preload.src }
        }))
        // Trigger queue advance (without playing since we already started)
        document.dispatchEvent(new CustomEvent("queue:next"))
      }
    }
    requestAnimationFrame(fade)
  }

  setCrossfade(event) {
    const duration = parseInt(event.currentTarget.dataset.duration)
    localStorage.setItem("crossfadeDuration", duration.toString())
  }

  // Playback speed (podcasts)

  setSpeed(event) {
    const rate = parseFloat(event.currentTarget.dataset.rate)
    this.audio.playbackRate = rate
    localStorage.setItem("podcastPlaybackRate", rate.toString())
    if (this.hasSpeedDisplayTarget) {
      this.speedDisplayTarget.textContent = `${rate}x`
    }
  }

  _applyPlaybackRate() {
    if (this.currentIsPodcast) {
      const rate = parseFloat(localStorage.getItem("podcastPlaybackRate") || "1")
      this.audio.playbackRate = rate
      this._showSpeedControl(true, rate)
    } else {
      this.audio.playbackRate = 1.0
      this._showSpeedControl(false, 1.0)
    }
  }

  _showSpeedControl(show, rate) {
    if (this.hasSpeedControlTarget) {
      this.speedControlTarget.classList.toggle("hidden", !show)
    }
    if (this.hasSpeedDisplayTarget) {
      this.speedDisplayTarget.textContent = `${rate}x`
    }
  }

  formatTime(seconds) {
    if (!seconds || isNaN(seconds) || !isFinite(seconds)) return "0:00"
    const mins = Math.floor(seconds / 60)
    const secs = Math.floor(seconds % 60)
    return `${mins}:${secs.toString().padStart(2, "0")}`
  }
}
