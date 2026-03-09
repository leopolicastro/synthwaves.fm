import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["video", "placeholder", "error", "loading", "channelName"]
  static values = { autoplayUrl: String, autoplayName: String }

  connect() {
    this.hls = null
    this.networkRetries = 0

    // Pre-load hls.js so it's available synchronously on click
    this.hlsClass = null
    import("hls.js").then(mod => { this.hlsClass = mod.default }).catch(() => {})

    // Auto-play on show page (works with Turbo navigation)
    if (this.hasAutoplayUrlValue && this.autoplayUrlValue) {
      this.play({ detail: { url: this.autoplayUrlValue, name: this.autoplayNameValue } })
    }
  }

  disconnect() {
    this.destroyPlayer()
  }

  play(event) {
    const { url, name } = event.params || event.detail || {}
    if (!url) return

    this.networkRetries = 0
    this.showLoading()
    this.hideError()
    this.updateChannelName(name)

    // Pause any music/YouTube playing through the bottom player
    const audio = document.getElementById("persistent-audio")
    if (audio && !audio.paused) audio.pause()
    document.dispatchEvent(new CustomEvent("youtube:stop"))

    const video = this.videoTarget
    video.classList.remove("hidden")
    if (this.hasPlaceholderTarget) this.placeholderTarget.classList.add("hidden")

    this.destroyPlayer()

    if (video.canPlayType("application/vnd.apple.mpegurl")) {
      // Safari: native HLS support (no CORS issues)
      this.playNative(video, url)
    } else if (this.hlsClass) {
      this.setupHls(video, url)
    } else {
      // Fallback: load hls.js async (may fail autoplay in strict browsers)
      this.loadHlsAsync(video, url)
    }
  }

  playNative(video, url) {
    video.src = url

    video.onerror = () => {
      this.showError("Stream unavailable. The channel may be offline.")
    }

    video.play().then(() => {
      this.hideLoading()
    }).catch(() => {
      // Autoplay blocked — just show controls, user can click play
      this.hideLoading()
    })
  }

  setupHls(video, url) {
    const Hls = this.hlsClass
    if (!Hls.isSupported()) {
      this.showError("HLS playback is not supported in this browser.")
      return
    }

    this.hls = new Hls({ enableWorker: true, lowLatencyMode: true })

    this.hls.on(Hls.Events.MANIFEST_PARSED, () => {
      video.play().then(() => {
        this.hideLoading()
      }).catch(() => {
        // Autoplay blocked — just show controls, user can click play
        this.hideLoading()
      })
    })

    this.hls.on(Hls.Events.ERROR, (_event, data) => {
      if (data.fatal) this.handleHlsError(Hls, data)
    })

    this.hls.loadSource(url)
    this.hls.attachMedia(video)
  }

  async loadHlsAsync(video, url) {
    try {
      const { default: Hls } = await import("hls.js")
      this.hlsClass = Hls
      this.setupHls(video, url)
    } catch {
      this.showError("Failed to load HLS player.")
    }
  }

  handleHlsError(Hls, data) {
    switch (data.type) {
      case Hls.ErrorTypes.NETWORK_ERROR:
        this.networkRetries++
        if (this.networkRetries <= 3) {
          this.hls.startLoad()
        } else {
          this.showError("Stream unavailable. It may be offline or blocked by CORS.")
          this.destroyPlayer()
        }
        break
      case Hls.ErrorTypes.MEDIA_ERROR:
        this.hls.recoverMediaError()
        break
      default:
        this.showError("Stream unavailable. The channel may be offline.")
        this.destroyPlayer()
        break
    }
  }

  destroyPlayer() {
    if (this.hls) {
      this.hls.destroy()
      this.hls = null
    }
  }

  showLoading() {
    if (this.hasLoadingTarget) this.loadingTarget.classList.remove("hidden")
  }

  hideLoading() {
    if (this.hasLoadingTarget) this.loadingTarget.classList.add("hidden")
  }

  showError(message) {
    this.hideLoading()
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = message
      this.errorTarget.classList.remove("hidden")
    }
  }

  hideError() {
    if (this.hasErrorTarget) this.errorTarget.classList.add("hidden")
  }

  updateChannelName(name) {
    if (this.hasChannelNameTarget && name) {
      this.channelNameTarget.textContent = name
    }
  }
}
