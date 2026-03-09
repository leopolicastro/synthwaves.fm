import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.hidePlayerBar()
    this.pauseAllAudio()
  }

  disconnect() {
    this.showPlayerBar()
  }

  hidePlayerBar() {
    const playerBar = document.getElementById("player-bar")
    if (playerBar) playerBar.classList.add("hidden")

    const queuePanel = document.getElementById("queue-panel-container")
    if (queuePanel) queuePanel.classList.add("hidden")

    document.body.classList.remove("pb-24")
  }

  showPlayerBar() {
    const playerBar = document.getElementById("player-bar")
    if (playerBar) playerBar.classList.remove("hidden")

    const queuePanel = document.getElementById("queue-panel-container")
    if (queuePanel) queuePanel.classList.remove("hidden")

    document.body.classList.add("pb-24")
  }

  pauseAllAudio() {
    const audio = document.getElementById("persistent-audio")
    if (audio && !audio.paused) audio.pause()

    document.dispatchEvent(new CustomEvent("youtube:stop"))
  }
}
