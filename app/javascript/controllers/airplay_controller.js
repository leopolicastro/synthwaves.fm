import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button"]

  connect() {
    // AirPlay is Safari-only
    if (!window.WebKitPlaybackTargetAvailabilityEvent) return

    this._airplayActive = false

    this._availabilityHandler = (e) => {
      if (e.availability === "available") {
        this.buttonTarget.classList.remove("hidden")
      } else {
        this.buttonTarget.classList.add("hidden")
      }
    }

    this._wirelessHandler = () => {
      const audio = this._audio()
      if (!audio) return
      const active = audio.webkitCurrentPlaybackTargetIsWireless || false
      this._airplayActive = active

      // Update button styling
      if (this.hasButtonTarget) {
        if (active) {
          this.buttonTarget.classList.remove("text-gray-500")
          this.buttonTarget.classList.add("text-neon-cyan")
        } else {
          this.buttonTarget.classList.add("text-gray-500")
          this.buttonTarget.classList.remove("text-neon-cyan")
        }
      }

      document.dispatchEvent(new CustomEvent("airplay:stateChanged", {
        detail: { active }
      }))
    }

    this._bindToAudio()

    // The persistent-audio element is created lazily by the player controller,
    // so watch for it if it doesn't exist yet.
    if (!this._audio()) {
      this._observer = new MutationObserver(() => {
        if (this._audio()) {
          this._bindToAudio()
          this._observer.disconnect()
          this._observer = null
        }
      })
      this._observer.observe(document.documentElement, { childList: true })
    }
  }

  disconnect() {
    const audio = this._audio()
    if (audio) {
      if (this._availabilityHandler) {
        audio.removeEventListener("webkitplaybacktargetavailabilitychanged", this._availabilityHandler)
      }
      if (this._wirelessHandler) {
        audio.removeEventListener("webkitcurrentplaybacktargetiswirelesschanged", this._wirelessHandler)
      }
    }
    if (this._observer) {
      this._observer.disconnect()
      this._observer = null
    }
  }

  pick() {
    const audio = this._audio()
    if (audio?.webkitShowPlaybackTargetPicker) {
      audio.webkitShowPlaybackTargetPicker()
    }
  }

  _bindToAudio() {
    const audio = this._audio()
    if (!audio) return

    if (this._availabilityHandler) {
      audio.addEventListener("webkitplaybacktargetavailabilitychanged", this._availabilityHandler)
    }
    if (this._wirelessHandler) {
      audio.addEventListener("webkitcurrentplaybacktargetiswirelesschanged", this._wirelessHandler)
    }
  }

  _audio() {
    return document.getElementById("persistent-audio")
  }
}
