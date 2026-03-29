import { Controller } from "@hotwired/stimulus"

// Manages view switching between the TV guide and TV player on the public TV guide page.
// When a channel is tuned, the guide hides and the player fills the screen.
// "Back to Guide" reverses this.
export default class extends Controller {
  static targets = ["guide", "player"]

  connect() {
    this._onPlay = () => this.showPlayer()
    document.addEventListener("video:playNow", this._onPlay)
  }

  disconnect() {
    document.removeEventListener("video:playNow", this._onPlay)
  }

  showPlayer() {
    this.guideTarget.classList.add("hidden")
    this.playerTarget.classList.remove("hidden")
    window.scrollTo({ top: 0, behavior: "instant" })
  }

  showGuide() {
    this.playerTarget.classList.add("hidden")
    this.guideTarget.classList.remove("hidden")

    // Close the HLS player
    const tvPlayer = document.getElementById("tv-player")
    if (tvPlayer) {
      const hlsCtrl = this.application.getControllerForElementAndIdentifier(tvPlayer, "hls-player")
      if (hlsCtrl) hlsCtrl.close()
    }
  }
}
