import { Controller } from "@hotwired/stimulus"

// Manages the YouTube IFrame Player API and a floating PiP video window.
//
// This controller lives on the permanent player bar (#player-bar).
// The PiP container is created dynamically via JS and appended to
// document.body — Turbo never touches it, so the iframe survives
// page navigations without reloading.
export default class extends Controller {
  connect() {
    this.playHandler = (e) => this.play(e.detail)
    this.stopHandler = () => this.stop()
    this.toggleHandler = () => this.toggle()
    this.musicVideoShowingHandler = () => this.hidePip()
    this.musicVideoHiddenHandler = () => this._restorePipIfActive()

    document.addEventListener("youtube:play", this.playHandler)
    document.addEventListener("youtube:stop", this.stopHandler)
    document.addEventListener("youtube:toggle", this.toggleHandler)
    document.addEventListener("music-video:showing", this.musicVideoShowingHandler)
    document.addEventListener("music-video:hidden", this.musicVideoHiddenHandler)
  }

  disconnect() {
    document.removeEventListener("youtube:play", this.playHandler)
    document.removeEventListener("youtube:stop", this.stopHandler)
    document.removeEventListener("youtube:toggle", this.toggleHandler)
    document.removeEventListener("music-video:showing", this.musicVideoShowingHandler)
    document.removeEventListener("music-video:hidden", this.musicVideoHiddenHandler)
  }

  get pip() {
    return this._ensurePip()
  }

  get player() {
    return this.pip._ytPlayer || null
  }

  set player(value) {
    this.pip._ytPlayer = value
  }

  get apiReady() {
    return window._ytApiReady || false
  }

  set apiReady(value) {
    window._ytApiReady = value
  }

  play({ videoId, isLive }) {
    this.pip._ytIsLive = isLive || false

    if (!this.apiReady) {
      this.pip._ytPendingVideoId = videoId
      this.pip._ytPendingIsLive = isLive || false
      this.loadApi()
      return
    }

    if (this.player) {
      this.player.loadVideoById(videoId)
    } else {
      this.createPlayer(videoId)
    }

    this.showPip()
  }

  toggle() {
    if (!this.player) return

    const state = this.player.getPlayerState()
    if (state === YT.PlayerState.PLAYING) {
      this.player.pauseVideo()
    } else {
      this.player.playVideo()
    }
  }

  stop() {
    if (this.player) {
      this.player.stopVideo()
    }
    this.stopTimeUpdates()
    this.hidePip()
    document.dispatchEvent(new CustomEvent("youtube:stopped"))
  }

  // Private

  _ensurePip() {
    let pip = document.getElementById("youtube-pip")
    if (!pip) {
      pip = document.createElement("div")
      pip.id = "youtube-pip"
      pip.className = "hidden fixed bottom-28 right-4 z-50 rounded-lg shadow-2xl overflow-hidden"
      pip.innerHTML = `
        <div class="relative">
          <div id="youtube-pip-iframe"></div>
          <button type="button"
                  class="absolute top-1 right-1 w-6 h-6 bg-black/60 hover:bg-black/80 text-white rounded-full flex items-center justify-center"
                  id="youtube-pip-close">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/></svg>
          </button>
        </div>
      `
      // Append to <html> instead of <body> so Turbo's body
      // replacement never detaches the iframe (which would reload it).
      document.documentElement.appendChild(pip)
      pip.querySelector("#youtube-pip-close").addEventListener("click", () => this.stop())
    }
    return pip
  }

  get iframeTarget() {
    return document.getElementById("youtube-pip-iframe")
  }

  loadApi() {
    if (window.YT && window.YT.Player) {
      this.apiReady = true
      this.onApiReady()
      return
    }

    if (document.querySelector('script[src*="youtube.com/iframe_api"]')) {
      const originalCallback = window.onYouTubeIframeAPIReady
      window.onYouTubeIframeAPIReady = () => {
        if (originalCallback) originalCallback()
        this.apiReady = true
        this.onApiReady()
      }
      return
    }

    window.onYouTubeIframeAPIReady = () => {
      this.apiReady = true
      this.onApiReady()
    }

    const script = document.createElement("script")
    script.src = "https://www.youtube.com/iframe_api"
    document.head.appendChild(script)
  }

  onApiReady() {
    const pip = this.pip
    if (pip._ytPendingVideoId) {
      const videoId = pip._ytPendingVideoId
      const isLive = pip._ytPendingIsLive || false
      pip._ytPendingVideoId = null
      pip._ytPendingIsLive = false
      pip._ytIsLive = isLive
      this.createPlayer(videoId)
      this.showPip()
    }
  }

  createPlayer(videoId) {
    if (this.player) {
      this.player.destroy()
      this.player = null
    }

    // YT.Player replaces the target div with an iframe, so recreate it if needed
    let target = this.iframeTarget
    if (!target || target.tagName === "IFRAME") {
      const parent = this.pip.querySelector(".relative")
      const old = target || parent.querySelector("iframe")
      if (old) old.remove()
      const div = document.createElement("div")
      div.id = "youtube-pip-iframe"
      parent.insertBefore(div, parent.firstChild)
      target = div
    }

    this.player = new YT.Player(target, {
      height: "144",
      width: "256",
      videoId: videoId,
      playerVars: {
        autoplay: 1,
        controls: 0,
        modestbranding: 1,
        rel: 0,
        playsinline: 1
      },
      events: {
        onReady: () => this.onPlayerReady(),
        onStateChange: (e) => this.onStateChange(e)
      }
    })
  }

  onPlayerReady() {
    this.player.playVideo()
  }

  onStateChange(event) {
    const isLive = this.pip._ytIsLive || false

    switch (event.data) {
      case YT.PlayerState.PLAYING:
        document.dispatchEvent(new CustomEvent("youtube:stateChange", {
          detail: { state: "playing" }
        }))
        if (!isLive) {
          this.startTimeUpdates()
        }
        break
      case YT.PlayerState.PAUSED:
        document.dispatchEvent(new CustomEvent("youtube:stateChange", {
          detail: { state: "paused" }
        }))
        this.stopTimeUpdates()
        break
      case YT.PlayerState.ENDED:
        this.stopTimeUpdates()
        document.dispatchEvent(new CustomEvent("youtube:stateChange", {
          detail: { state: "ended" }
        }))
        break
    }
  }

  startTimeUpdates() {
    this.stopTimeUpdates()
    const interval = setInterval(() => {
      const p = this.player
      if (p && p.getCurrentTime) {
        document.dispatchEvent(new CustomEvent("youtube:timeUpdate", {
          detail: {
            currentTime: p.getCurrentTime(),
            duration: p.getDuration()
          }
        }))
      }
    }, 500)
    this.pip._ytInterval = interval
  }

  stopTimeUpdates() {
    const pip = document.getElementById("youtube-pip")
    if (pip && pip._ytInterval) {
      clearInterval(pip._ytInterval)
      pip._ytInterval = null
    }
  }

  showPip() {
    this.pip.classList.remove("hidden")
  }

  hidePip() {
    this.pip.classList.add("hidden")
  }

  _restorePipIfActive() {
    if (this.player) {
      this.showPip()
    }
  }
}
