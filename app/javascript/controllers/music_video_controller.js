import { Controller } from "@hotwired/stimulus"

// Syncs a muted YouTube video to the currently playing audio track.
// Uses the YT IFrame API (already loaded by youtube_player_controller)
// to control playback position, play/pause state, and seeking.
//
// Binds to BOTH the HTML5 <audio> element and the YouTube PiP player
// so it works regardless of which audio source is active.
export default class extends Controller {
  static targets = ["container", "header"]
  static values = { trackId: Number, youtubeVideoId: String }

  connect() {
    this._currentVideoId = null
    this._ytPlayer = null
    this._syncInterval = null

    this._nowPlayingHandler = (e) => this._onNowPlaying(e.detail)
    this._ytTimeHandler = (e) => this._onPipTimeUpdate(e.detail)
    document.addEventListener("player:nowPlaying", this._nowPlayingHandler)
    document.addEventListener("youtube:timeUpdate", this._ytTimeHandler)

    // Pinned mode: embed immediately
    if (this.hasYoutubeVideoIdValue && this.youtubeVideoIdValue) {
      this._embed(this.youtubeVideoIdValue)
    }
  }

  disconnect() {
    document.removeEventListener("player:nowPlaying", this._nowPlayingHandler)
    document.removeEventListener("youtube:timeUpdate", this._ytTimeHandler)
    this._destroyPlayer()
    this._unbindAudio()
    this._dispatchHidden()
    this._currentVideoId = null
  }

  _onNowPlaying({ trackId, youtubeVideoId }) {
    if (!trackId) return
    if (this.hasTrackIdValue && this.trackIdValue) return

    if (youtubeVideoId) {
      this._embed(youtubeVideoId)
    } else {
      this._clear()
    }
  }

  // PiP sends time updates every 500ms — use these to sync YouTube-only tracks
  _onPipTimeUpdate({ currentTime }) {
    if (!this._ytPlayer || !this._ytPlayer.getCurrentTime) return
    // Only sync to PiP if audio element is NOT actively playing this track
    if (this._audio && !this._audio.paused && this._audio.src) return

    this._lastPipTime = currentTime
    // Sync on first PiP update (start playback if paused)
    if (!this._pipSyncStarted) {
      this._pipSyncStarted = true
      this._ytPlayer.seekTo(currentTime, true)
      this._ytPlayer.playVideo()
      this._startPipSync()
    }
  }

  _embed(videoId) {
    if (this._currentVideoId === videoId) return
    if (!this.hasContainerTarget) return

    this._destroyPlayer()
    this._unbindAudio()
    this._currentVideoId = videoId
    this._pipSyncStarted = false
    this._lastPipTime = 0

    this.element.classList.remove("hidden")
    this._dispatchShowing(videoId)

    this._ensureApiThenCreate(videoId)
  }

  _ensureApiThenCreate(videoId) {
    if (window.YT && window.YT.Player) {
      this._createPlayer(videoId)
      return
    }

    // API not loaded yet — wait for it
    const prevCallback = window.onYouTubeIframeAPIReady
    window.onYouTubeIframeAPIReady = () => {
      if (prevCallback) prevCallback()
      if (this._currentVideoId === videoId) {
        this._createPlayer(videoId)
      }
    }

    if (!document.querySelector('script[src*="youtube.com/iframe_api"]')) {
      const script = document.createElement("script")
      script.src = "https://www.youtube.com/iframe_api"
      document.head.appendChild(script)
    }
  }

  _createPlayer(videoId) {
    this.containerTarget.innerHTML = ""
    const div = document.createElement("div")
    this.containerTarget.appendChild(div)

    this._ytPlayer = new YT.Player(div, {
      width: "100%",
      height: "100%",
      videoId: videoId,
      playerVars: {
        autoplay: 1,
        mute: 1,
        controls: 0,
        modestbranding: 1,
        rel: 0,
        playsinline: 1,
        disablekb: 1
      },
      events: {
        onReady: (e) => {
          // Ensure iframe fills container
          const iframe = e.target.getIframe()
          iframe.style.width = "100%"
          iframe.style.height = "100%"
          this._onPlayerReady()
        }
      }
    })
  }

  _onPlayerReady() {
    if (!this._ytPlayer) return
    this._ytPlayer.mute()

    // Always bind to audio element for sync
    this._bindAudio()

    // If audio is already playing, sync immediately
    if (this._audio && !this._audio.paused && this._audio.src) {
      this._syncToAudio()
    }
    // Otherwise, PiP time updates (youtube:timeUpdate) will handle sync
    // for YouTube-only tracks, and audio play events will handle audio tracks
  }

  // --- HTML5 <audio> sync ---

  _bindAudio() {
    this._audio = document.getElementById("persistent-audio")
    if (!this._audio) {
      // Audio element not created yet — watch for it
      this._audioObserver = new MutationObserver(() => {
        const el = document.getElementById("persistent-audio")
        if (el) {
          this._audio = el
          this._attachAudioListeners()
          this._audioObserver.disconnect()
          this._audioObserver = null
        }
      })
      this._audioObserver.observe(document.documentElement, { childList: true })
      return
    }

    this._attachAudioListeners()
  }

  _attachAudioListeners() {
    if (!this._audio) return

    this._onAudioPlay = () => {
      this._pipSyncStarted = false // audio takes priority over PiP
      this._syncToAudio()
    }
    this._onAudioPause = () => {
      if (this._ytPlayer) this._ytPlayer.pauseVideo()
      this._stopSync()
    }
    this._onAudioSeeked = () => this._seekVideoToAudio()

    this._audio.addEventListener("play", this._onAudioPlay)
    this._audio.addEventListener("pause", this._onAudioPause)
    this._audio.addEventListener("seeked", this._onAudioSeeked)
  }

  _unbindAudio() {
    if (this._audioObserver) {
      this._audioObserver.disconnect()
      this._audioObserver = null
    }
    if (this._audio) {
      if (this._onAudioPlay) this._audio.removeEventListener("play", this._onAudioPlay)
      if (this._onAudioPause) this._audio.removeEventListener("pause", this._onAudioPause)
      if (this._onAudioSeeked) this._audio.removeEventListener("seeked", this._onAudioSeeked)
      this._audio = null
    }
    this._stopSync()
  }

  _syncToAudio() {
    if (!this._ytPlayer || !this._audio) return

    this._seekVideoToAudio()

    if (!this._audio.paused) {
      this._ytPlayer.playVideo()
      this._startAudioSync()
    }
  }

  _seekVideoToAudio() {
    if (!this._ytPlayer || !this._audio) return
    this._ytPlayer.seekTo(this._audio.currentTime, true)
  }

  _startAudioSync() {
    this._stopSync()
    this._syncInterval = setInterval(() => {
      if (!this._ytPlayer || !this._audio || !this._ytPlayer.getCurrentTime) return
      const drift = Math.abs(this._ytPlayer.getCurrentTime() - this._audio.currentTime)
      if (drift > 2) {
        this._ytPlayer.seekTo(this._audio.currentTime, true)
      }
    }, 3000)
  }

  // --- YouTube PiP sync (for YouTube-only tracks) ---

  _startPipSync() {
    this._stopSync()
    this._syncInterval = setInterval(() => {
      if (!this._ytPlayer || !this._ytPlayer.getCurrentTime) return
      const drift = Math.abs(this._ytPlayer.getCurrentTime() - this._lastPipTime)
      if (drift > 2) {
        this._ytPlayer.seekTo(this._lastPipTime, true)
      }
    }, 3000)
  }

  // --- Cleanup ---

  _stopSync() {
    if (this._syncInterval) {
      clearInterval(this._syncInterval)
      this._syncInterval = null
    }
  }

  _destroyPlayer() {
    this._stopSync()
    if (this._ytPlayer) {
      try { this._ytPlayer.destroy() } catch (e) { /* ignore */ }
      this._ytPlayer = null
    }
  }

  _clear() {
    this._destroyPlayer()
    this._unbindAudio()
    this._currentVideoId = null
    this._pipSyncStarted = false
    if (this.hasContainerTarget) {
      this.containerTarget.innerHTML = ""
    }
    this.element.classList.add("hidden")
    this._dispatchHidden()
  }

  _dispatchShowing(videoId) {
    document.dispatchEvent(new CustomEvent("music-video:showing", { detail: { videoId } }))
  }

  _dispatchHidden() {
    document.dispatchEvent(new CustomEvent("music-video:hidden"))
  }
}
