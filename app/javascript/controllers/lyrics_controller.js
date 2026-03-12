import { Controller } from "@hotwired/stimulus"

const LRC_REGEX = /\[(\d{2,}):(\d{2})\.(\d{2,3})\](.*)/

export default class extends Controller {
  static targets = ["content"]
  static values = { trackId: Number }

  connect() {
    this._syncedLines = null
    this._activeLineIndex = -1

    this._onTimeUpdate = () => this._highlightLine()
    this._bindToAudio()

    if (!this._audio) {
      this._observer = new MutationObserver(() => {
        if (document.getElementById("persistent-audio")) {
          this._bindToAudio()
          this._observer.disconnect()
          this._observer = null
        }
      })
      this._observer.observe(document.documentElement, { childList: true })
    }

    // If pinned to a track, fetch immediately
    if (this.hasTrackIdValue && this.trackIdValue) {
      this._fetchLyrics(this.trackIdValue)
    }

    this._nowPlayingHandler = (e) => this._onNowPlaying(e.detail)
    document.addEventListener("player:nowPlaying", this._nowPlayingHandler)
  }

  disconnect() {
    document.removeEventListener("player:nowPlaying", this._nowPlayingHandler)
    if (this._audio) {
      this._audio.removeEventListener("timeupdate", this._onTimeUpdate)
    }
    if (this._observer) {
      this._observer.disconnect()
      this._observer = null
    }
  }

  _bindToAudio() {
    this._audio = document.getElementById("persistent-audio")
    if (this._audio) {
      this._audio.addEventListener("timeupdate", this._onTimeUpdate)
    }
  }

  _onNowPlaying({ trackId }) {
    if (!trackId) return
    // If pinned to a specific track, don't follow now-playing
    if (this.hasTrackIdValue && this.trackIdValue) return
    this._fetchLyrics(trackId)
  }

  async _fetchLyrics(trackId) {
    if (!this.hasContentTarget) return
    this.contentTarget.innerHTML = ""
    this._syncedLines = null
    this._activeLineIndex = -1

    try {
      const response = await fetch(`/tracks/${trackId}/lyrics.json`)
      if (!response.ok) return
      const data = await response.json()
      if (!data.lyrics) {
        this.contentTarget.innerHTML = '<span class="text-gray-400">No lyrics available</span>'
        return
      }

      const parsed = this._parseLRC(data.lyrics)
      if (parsed) {
        this._syncedLines = parsed
        this._renderSyncedLines()
      } else {
        this.contentTarget.textContent = data.lyrics
        this.contentTarget.classList.add("whitespace-pre-line", "text-gray-400")
      }
    } catch (e) {
      this.contentTarget.innerHTML = '<span class="text-gray-400">No lyrics available</span>'
    }
  }

  _parseLRC(text) {
    const lines = []
    for (const raw of text.split("\n")) {
      const match = LRC_REGEX.exec(raw)
      if (match) {
        const mins = parseInt(match[1])
        const secs = parseInt(match[2])
        let ms = parseInt(match[3])
        if (match[3].length === 2) ms *= 10
        const time = mins * 60 + secs + ms / 1000
        lines.push({ time, text: match[4].trim() })
      }
    }
    return lines.length > 0 ? lines : null
  }

  _renderSyncedLines() {
    if (!this.hasContentTarget || !this._syncedLines) return
    this.contentTarget.innerHTML = ""

    for (const line of this._syncedLines) {
      const el = document.createElement("p")
      el.textContent = line.text || "\u00A0"
      el.className = "py-1 transition-all duration-300 text-gray-400"
      this.contentTarget.appendChild(el)
    }
  }

  _highlightLine() {
    if (!this._syncedLines || !this._audio || !this.hasContentTarget) return

    const currentTime = this._audio.currentTime
    let activeIndex = -1

    for (let i = this._syncedLines.length - 1; i >= 0; i--) {
      if (currentTime >= this._syncedLines[i].time) {
        activeIndex = i
        break
      }
    }

    if (activeIndex === this._activeLineIndex) return
    this._activeLineIndex = activeIndex

    const children = this.contentTarget.children
    for (let i = 0; i < children.length; i++) {
      if (i === activeIndex) {
        children[i].className = "py-1 transition-all duration-300 text-white font-semibold scale-105"
      } else {
        children[i].className = "py-1 transition-all duration-300 text-gray-400"
      }
    }

    if (activeIndex >= 0 && children[activeIndex]) {
      children[activeIndex].scrollIntoView({ behavior: "smooth", block: "center" })
    }
  }
}
