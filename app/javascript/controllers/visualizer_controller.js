import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["canvas", "container", "status"]

  connect() {
    this.audio = document.getElementById("persistent-audio")
    if (!this.audio) return

    this._visible = false
    this._airplayActive = false
    this._readThemeColors()

    this._onPlay = () => this._setActive(true)
    this._onPause = () => this._setActive(false)
    this.audio.addEventListener("play", this._onPlay)
    this.audio.addEventListener("pause", this._onPause)

    this._resizeObserver = new ResizeObserver(() => {
      if (this._visible) this._setupCanvas()
    })
    this._resizeObserver.observe(this.containerTarget)

    this._themeObserver = new MutationObserver(() => this._readThemeColors())
    this._themeObserver.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["data-theme"]
    })

    this._visibilityHandler = (e) => this._onVisibilityChanged(e.detail)
    document.addEventListener("visualizer-panel:visibilityChanged", this._visibilityHandler)

    this._sourceChangedHandler = (e) => this._onSourceChanged(e.detail)
    document.addEventListener("player:sourceChanged", this._sourceChangedHandler)

    this._airplayHandler = (e) => this._onAirplayStateChanged(e.detail)
    document.addEventListener("airplay:stateChanged", this._airplayHandler)

    this._setActive(!this.audio.paused && !!this.audio.src)
  }

  disconnect() {
    if (this._frameId) cancelAnimationFrame(this._frameId)
    if (this._resizeObserver) this._resizeObserver.disconnect()
    if (this._themeObserver) this._themeObserver.disconnect()
    if (this._syncInterval) clearInterval(this._syncInterval)

    if (this.audio) {
      this.audio.removeEventListener("play", this._onPlay)
      this.audio.removeEventListener("pause", this._onPause)
    }

    document.removeEventListener("visualizer-panel:visibilityChanged", this._visibilityHandler)
    document.removeEventListener("player:sourceChanged", this._sourceChangedHandler)
    document.removeEventListener("airplay:stateChanged", this._airplayHandler)

    this._teardownShadow()
  }

  // Private

  _onAirplayStateChanged({ active }) {
    this._airplayActive = active
    if (active && this._visible) {
      // Close visualizer when AirPlay becomes active
      document.dispatchEvent(new CustomEvent("visualizer-panel:close"))
    }
  }

  _onVisibilityChanged({ visible }) {
    this._visible = visible
    if (visible) {
      if (this._airplayActive) {
        this._showStatus("Visualizer unavailable during AirPlay")
        return
      }
      this._initAudioNodes()
      this._setupCanvas()
      this._animate()
      this._startSync()
    } else {
      if (this._frameId) {
        cancelAnimationFrame(this._frameId)
        this._frameId = null
      }
      this._stopSync()
      this._pauseShadow()
    }
  }

  _onSourceChanged({ streamUrl }) {
    if (!this._visible || !this._shadowAudio) return
    this._updateShadowSrc(streamUrl)
  }

  _initAudioNodes() {
    if (this._audioContext && this._analyser) return

    try {
      const shadow = this._ensureShadowAudio()
      this._updateShadowSrc(this.audio.src)

      const ctx = new (window.AudioContext || window.webkitAudioContext)()
      const source = ctx.createMediaElementSource(shadow)
      const analyser = ctx.createAnalyser()
      analyser.fftSize = 256
      source.connect(analyser)
      analyser.connect(ctx.destination)

      this._audioContext = ctx
      this._sourceNode = source
      this._analyser = analyser
    } catch (e) {
      console.warn("Visualizer: could not init Web Audio nodes", e)
    }
  }

  _ensureShadowAudio() {
    let shadow = document.getElementById("persistent-audio-visualizer")
    if (!shadow) {
      shadow = document.createElement("audio")
      shadow.id = "persistent-audio-visualizer"
      shadow.crossOrigin = "anonymous"
      shadow.preload = "auto"
      shadow.volume = 0
      document.documentElement.appendChild(shadow)
    }
    this._shadowAudio = shadow
    return shadow
  }

  _updateShadowSrc(streamUrl) {
    if (!this._shadowAudio || !streamUrl) return
    // Use proxy URL for same-origin access (Web Audio API requires CORS)
    const proxyUrl = streamUrl.includes("?") ? `${streamUrl}&proxy=1` : `${streamUrl}?proxy=1`
    if (this._shadowAudio.src !== proxyUrl) {
      this._shadowAudio.src = proxyUrl
      this._shadowAudio.load()
    }
    // Sync playback state
    if (!this.audio.paused) {
      this._shadowAudio.currentTime = this.audio.currentTime
      this._shadowAudio.play().catch(() => {})
    }
  }

  _startSync() {
    this._stopSync()
    this._syncInterval = setInterval(() => {
      if (!this._shadowAudio || !this.audio) return

      // Mirror play/pause
      if (!this.audio.paused && this._shadowAudio.paused) {
        this._shadowAudio.play().catch(() => {})
      } else if (this.audio.paused && !this._shadowAudio.paused) {
        this._shadowAudio.pause()
      }

      // Sync time if drifted
      if (!this.audio.paused && Math.abs(this.audio.currentTime - this._shadowAudio.currentTime) > 0.5) {
        this._shadowAudio.currentTime = this.audio.currentTime
      }
    }, 1000)
  }

  _stopSync() {
    if (this._syncInterval) {
      clearInterval(this._syncInterval)
      this._syncInterval = null
    }
  }

  _pauseShadow() {
    if (this._shadowAudio) {
      this._shadowAudio.pause()
      this._shadowAudio.removeAttribute("src")
      this._shadowAudio.load()
    }
  }

  _teardownShadow() {
    this._stopSync()
    if (this._shadowAudio) {
      this._shadowAudio.pause()
      this._shadowAudio.removeAttribute("src")
    }
    if (this._audioContext) {
      this._audioContext.close().catch(() => {})
      this._audioContext = null
      this._analyser = null
      this._sourceNode = null
    }
  }

  _showStatus(message) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message
      this.statusTarget.classList.remove("hidden")
    }
  }

  _readThemeColors() {
    const style = getComputedStyle(document.documentElement)
    this._colorBase = style.getPropertyValue("--color-neon-pink").trim() || "#ff2d95"
    this._colorMid = style.getPropertyValue("--color-neon-purple").trim() || "#b026ff"
    this._colorTop = style.getPropertyValue("--color-neon-cyan").trim() || "#00f0ff"
  }

  _setupCanvas() {
    const canvas = this.canvasTarget
    const rect = this.containerTarget.getBoundingClientRect()
    canvas.width = rect.width * (window.devicePixelRatio || 1)
    canvas.height = rect.height * (window.devicePixelRatio || 1)
    canvas.style.width = `${rect.width}px`
    canvas.style.height = `${rect.height}px`
  }

  _setActive(active) {
    this._active = active
    if (this.hasStatusTarget) {
      this.statusTarget.classList.toggle("hidden", active)
    }
  }

  _animate() {
    if (!this._visible) return
    this._frameId = requestAnimationFrame(() => this._animate())
    this._draw()
  }

  _draw() {
    const canvas = this.canvasTarget
    const ctx = canvas.getContext("2d")
    const w = canvas.width
    const h = canvas.height
    const analyser = this._analyser

    ctx.clearRect(0, 0, w, h)

    const bufferLength = analyser ? analyser.frequencyBinCount : 64
    const dataArray = new Uint8Array(bufferLength)

    if (analyser && this._active) {
      analyser.getByteFrequencyData(dataArray)
    }

    const hasData = this._active && dataArray.some(v => v > 0)
    const barCount = Math.min(bufferLength, 64)
    const gap = 2 * (window.devicePixelRatio || 1)
    const barWidth = (w - gap * (barCount - 1)) / barCount
    const globalAlpha = hasData ? 1.0 : 0.3

    ctx.save()
    ctx.globalAlpha = globalAlpha

    for (let i = 0; i < barCount; i++) {
      const value = hasData ? dataArray[i] : 10 + Math.random() * 5
      const barHeight = (value / 255) * h * 0.9
      const x = i * (barWidth + gap)
      const y = h - barHeight

      const gradient = ctx.createLinearGradient(x, h, x, y)
      gradient.addColorStop(0, this._colorBase)
      gradient.addColorStop(0.5, this._colorMid)
      gradient.addColorStop(1, this._colorTop)

      ctx.fillStyle = gradient
      ctx.shadowColor = this._colorTop
      ctx.shadowBlur = hasData ? 8 : 2
      ctx.fillRect(x, y, barWidth, barHeight)
    }

    ctx.restore()
  }
}
