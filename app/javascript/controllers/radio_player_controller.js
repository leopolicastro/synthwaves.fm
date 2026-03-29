import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["audio", "toggleButton", "playIcon", "pauseIcon", "label"]
  static values = { url: String }

  toggle() {
    this.audioTarget.paused ? this.play() : this.pause()
  }

  play() {
    this.audioTarget.src = this.urlValue
    this.audioTarget.play()
    this.playIconTarget.classList.add("hidden")
    this.pauseIconTarget.classList.remove("hidden")
    this.labelTarget.textContent = "Listening"
  }

  pause() {
    this.audioTarget.pause()
    this.audioTarget.src = ""
    this.pauseIconTarget.classList.add("hidden")
    this.playIconTarget.classList.remove("hidden")
    this.labelTarget.textContent = "Listen Live"
  }
}
