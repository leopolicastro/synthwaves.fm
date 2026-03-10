import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button"]

  connect() {
    this.castSession = null
    this.castActive = false

    // Listen for player events to sync with cast
    this.playHandler = (e) => this.onPlayerPlay(e.detail)
    this.toggleHandler = () => this.onToggle()
    this.seekHandler = (e) => this.onSeek(e.detail)

    document.addEventListener("cast:loadMedia", this.playHandler)
    document.addEventListener("cast:toggle", this.toggleHandler)
    document.addEventListener("cast:seek", this.seekHandler)

    // Wait for Cast SDK to be available
    window.__onGCastApiAvailable = (isAvailable) => {
      if (isAvailable) {
        this.initializeCast()
      }
    }

    // If SDK already loaded
    if (window.cast && window.cast.framework) {
      this.initializeCast()
    }
  }

  disconnect() {
    document.removeEventListener("cast:loadMedia", this.playHandler)
    document.removeEventListener("cast:toggle", this.toggleHandler)
    document.removeEventListener("cast:seek", this.seekHandler)
  }

  initializeCast() {
    const context = cast.framework.CastContext.getInstance()
    context.setOptions({
      receiverApplicationId: chrome.cast.media.DEFAULT_MEDIA_RECEIVER_APP_ID,
      autoJoinPolicy: chrome.cast.AutoJoinPolicy.ORIGIN_SCOPED
    })

    context.addEventListener(
      cast.framework.CastContextEventType.SESSION_STATE_CHANGED,
      (event) => this.onSessionStateChanged(event)
    )

    // Show cast button if devices available
    this.showButton()
  }

  showButton() {
    if (this.hasButtonTarget) {
      this.buttonTarget.classList.remove("hidden")
    }
  }

  hideButton() {
    if (this.hasButtonTarget) {
      this.buttonTarget.classList.add("hidden")
    }
  }

  requestSession() {
    const context = cast.framework.CastContext.getInstance()
    context.requestSession().catch(() => {
      // User cancelled or no device selected
    })
  }

  onSessionStateChanged(event) {
    switch (event.sessionState) {
      case cast.framework.SessionState.SESSION_STARTED:
      case cast.framework.SessionState.SESSION_RESUMED:
        this.castSession = cast.framework.CastContext.getInstance().getCurrentSession()
        this.castActive = true
        this.dispatchCastState(true)
        break
      case cast.framework.SessionState.SESSION_ENDED:
        this.castSession = null
        this.castActive = false
        this.dispatchCastState(false)
        break
    }
  }

  dispatchCastState(active) {
    document.dispatchEvent(new CustomEvent("cast:stateChanged", {
      detail: { active }
    }))
  }

  onPlayerPlay({ streamUrl, title, artist }) {
    if (!this.castActive || !this.castSession) return
    if (!streamUrl) return // Skip YouTube tracks

    const mediaInfo = new chrome.cast.media.MediaInfo(streamUrl, "audio/mpeg")
    mediaInfo.metadata = new chrome.cast.media.MusicTrackMediaMetadata()
    mediaInfo.metadata.title = title || ""
    mediaInfo.metadata.artist = artist || ""

    const request = new chrome.cast.media.LoadRequest(mediaInfo)
    this.castSession.loadMedia(request).catch(() => {
      // Failed to load media on cast device
    })
  }

  onToggle() {
    if (!this.castActive || !this.castSession) return

    const media = this.castSession.getMediaSession()
    if (!media) return

    if (media.playerState === chrome.cast.media.PlayerState.PLAYING) {
      media.pause()
    } else {
      media.play()
    }
  }

  onSeek({ time }) {
    if (!this.castActive || !this.castSession) return

    const media = this.castSession.getMediaSession()
    if (!media) return

    const seekRequest = new chrome.cast.media.SeekRequest()
    seekRequest.currentTime = time
    media.seek(seekRequest)
  }
}
