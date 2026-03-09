import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["canvas", "container", "status"]

  connect() {
    this.audio = document.getElementById("persistent-audio")
    if (!this.audio) return

    this._visible = false
    this._initAudioNodes()
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

    this._setActive(!this.audio.paused && !!this.audio.src)
  }

  disconnect() {
    if (this._frameId) cancelAnimationFrame(this._frameId)
    if (this._resizeObserver) this._resizeObserver.disconnect()
    if (this._themeObserver) this._themeObserver.disconnect()

    if (this.audio) {
      this.audio.removeEventListener("play", this._onPlay)
      this.audio.removeEventListener("pause", this._onPause)
    }

    document.removeEventListener("visualizer-panel:visibilityChanged", this._visibilityHandler)
  }

  // Private

  _onVisibilityChanged({ visible }) {
    this._visible = visible
    if (visible) {
      this._setupCanvas()
      this._animate()
    } else {
      if (this._frameId) {
        cancelAnimationFrame(this._frameId)
        this._frameId = null
      }
    }
  }

  _initAudioNodes() {
    if (this.audio._audioContext && this.audio._analyser) return

    const ctx = new (window.AudioContext || window.webkitAudioContext)()
    const source = ctx.createMediaElementSource(this.audio)
    const analyser = ctx.createAnalyser()
    analyser.fftSize = 256
    source.connect(analyser)
    analyser.connect(ctx.destination)

    this.audio._audioContext = ctx
    this.audio._sourceNode = source
    this.audio._analyser = analyser
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
    const analyser = this.audio._analyser

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
