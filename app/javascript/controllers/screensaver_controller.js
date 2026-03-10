import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["canvas"]
  static values = { idleTimeout: { type: Number, default: 300000 } } // 5 minutes

  connect() {
    this._active = false
    this._mode = 0
    this._modes = ["starfield", "matrix", "waveform", "bounce"]
    this._stars = []
    this._matrixDrops = []
    this._bounceX = 100
    this._bounceY = 100
    this._bounceDx = 2
    this._bounceDy = 1.5
    this._readThemeColors()

    this._resetTimer()
    this._inputHandler = () => this._onInput()
    document.addEventListener("mousemove", this._inputHandler)
    document.addEventListener("keydown", this._inputHandler)
    document.addEventListener("touchstart", this._inputHandler)

    this._themeObserver = new MutationObserver(() => this._readThemeColors())
    this._themeObserver.observe(document.documentElement, {
      attributes: true, attributeFilter: ["data-theme"]
    })
  }

  disconnect() {
    this._deactivate()
    if (this._idleTimer) clearTimeout(this._idleTimer)
    document.removeEventListener("mousemove", this._inputHandler)
    document.removeEventListener("keydown", this._inputHandler)
    document.removeEventListener("touchstart", this._inputHandler)
    if (this._themeObserver) this._themeObserver.disconnect()
  }

  _readThemeColors() {
    const s = getComputedStyle(document.documentElement)
    this._colorPrimary = s.getPropertyValue("--color-neon-cyan").trim() || "#00f0ff"
    this._colorAccent = s.getPropertyValue("--color-neon-pink").trim() || "#ff2d95"
  }

  _resetTimer() {
    if (this._idleTimer) clearTimeout(this._idleTimer)
    this._idleTimer = setTimeout(() => this._tryActivate(), this.idleTimeoutValue)
  }

  _onInput() {
    if (this._active) {
      this._deactivate()
    }
    this._resetTimer()
  }

  _tryActivate() {
    const audio = document.getElementById("persistent-audio")
    if (!audio || audio.paused) return // Only activate when music is playing

    this._activate()
  }

  _activate() {
    this._active = true
    this._mode = Math.floor(Math.random() * this._modes.length)
    this.element.classList.remove("hidden")
    this._setupCanvas()
    this._initMode()
    this._animate()
    document.dispatchEvent(new CustomEvent("screensaver:activated"))
  }

  _deactivate() {
    if (!this._active) return
    this._active = false
    this.element.classList.add("hidden")
    if (this._frameId) cancelAnimationFrame(this._frameId)
    this._frameId = null
    document.dispatchEvent(new CustomEvent("screensaver:dismissed"))
  }

  _setupCanvas() {
    const canvas = this.canvasTarget
    const dpr = window.devicePixelRatio || 1
    canvas.width = window.innerWidth * dpr
    canvas.height = window.innerHeight * dpr
    canvas.style.width = `${window.innerWidth}px`
    canvas.style.height = `${window.innerHeight}px`
  }

  _initMode() {
    const mode = this._modes[this._mode]
    const w = this.canvasTarget.width
    const h = this.canvasTarget.height

    if (mode === "starfield") {
      this._stars = Array.from({ length: 200 }, () => ({
        x: Math.random() * w, y: Math.random() * h,
        z: Math.random() * 3 + 0.5, brightness: Math.random()
      }))
    } else if (mode === "matrix") {
      const cols = Math.floor(w / 16)
      this._matrixDrops = Array.from({ length: cols }, () => Math.random() * -100)
    } else if (mode === "bounce") {
      this._bounceX = w / 4
      this._bounceY = h / 4
      this._bounceDx = 2
      this._bounceDy = 1.5
    }
  }

  _animate() {
    if (!this._active) return
    this._frameId = requestAnimationFrame(() => this._animate())
    this._draw()
  }

  _draw() {
    const canvas = this.canvasTarget
    const ctx = canvas.getContext("2d")
    const w = canvas.width, h = canvas.height
    const mode = this._modes[this._mode]

    if (mode === "starfield") this._drawStarfield(ctx, w, h)
    else if (mode === "matrix") this._drawMatrix(ctx, w, h)
    else if (mode === "waveform") this._drawWaveform(ctx, w, h)
    else if (mode === "bounce") this._drawBounce(ctx, w, h)
  }

  _drawStarfield(ctx, w, h) {
    ctx.fillStyle = "rgba(0, 0, 0, 0.15)"
    ctx.fillRect(0, 0, w, h)
    const cx = w / 2, cy = h / 2
    for (const star of this._stars) {
      star.x += (star.x - cx) * 0.005 * star.z
      star.y += (star.y - cy) * 0.005 * star.z
      if (star.x < 0 || star.x > w || star.y < 0 || star.y > h) {
        star.x = cx + (Math.random() - 0.5) * 100
        star.y = cy + (Math.random() - 0.5) * 100
        star.z = Math.random() * 3 + 0.5
      }
      const size = star.z * 1.5
      ctx.fillStyle = this._colorPrimary
      ctx.globalAlpha = star.brightness * 0.8 + 0.2
      ctx.fillRect(star.x - size / 2, star.y - size / 2, size, size)
    }
    ctx.globalAlpha = 1
  }

  _drawMatrix(ctx, w, h) {
    ctx.fillStyle = "rgba(0, 0, 0, 0.05)"
    ctx.fillRect(0, 0, w, h)
    ctx.fillStyle = this._colorPrimary
    ctx.font = "14px monospace"
    const chars = "01"
    for (let i = 0; i < this._matrixDrops.length; i++) {
      const char = chars[Math.floor(Math.random() * chars.length)]
      ctx.fillText(char, i * 16, this._matrixDrops[i] * 16)
      if (this._matrixDrops[i] * 16 > h && Math.random() > 0.975) {
        this._matrixDrops[i] = 0
      }
      this._matrixDrops[i]++
    }
  }

  _drawWaveform(ctx, w, h) {
    ctx.fillStyle = "rgba(0, 0, 0, 0.1)"
    ctx.fillRect(0, 0, w, h)

    const audio = document.getElementById("persistent-audio")
    const analyser = audio?._analyser
    const bufLen = analyser ? analyser.frequencyBinCount : 64
    const data = new Uint8Array(bufLen)
    if (analyser) analyser.getByteFrequencyData(data)

    ctx.beginPath()
    ctx.strokeStyle = this._colorPrimary
    ctx.lineWidth = 2
    ctx.shadowColor = this._colorAccent
    ctx.shadowBlur = 10
    const sliceWidth = w / bufLen
    for (let i = 0; i < bufLen; i++) {
      const v = (data[i] || (Math.random() * 20)) / 255
      const y = h / 2 + (v - 0.5) * h * 0.6
      if (i === 0) ctx.moveTo(0, y)
      else ctx.lineTo(i * sliceWidth, y)
    }
    ctx.stroke()
    ctx.shadowBlur = 0
  }

  _drawBounce(ctx, w, h) {
    ctx.fillStyle = "rgba(0, 0, 0, 0.03)"
    ctx.fillRect(0, 0, w, h)

    const label = "synthwaves.fm"
    ctx.font = "bold 48px sans-serif"
    const metrics = ctx.measureText(label)
    const tw = metrics.width, th = 48

    this._bounceX += this._bounceDx
    this._bounceY += this._bounceDy
    if (this._bounceX + tw > w || this._bounceX < 0) this._bounceDx *= -1
    if (this._bounceY + th > h || this._bounceY - th < 0) this._bounceDy *= -1

    ctx.fillStyle = this._colorAccent
    ctx.shadowColor = this._colorPrimary
    ctx.shadowBlur = 20
    ctx.fillText(label, this._bounceX, this._bounceY)
    ctx.shadowBlur = 0
  }
}
