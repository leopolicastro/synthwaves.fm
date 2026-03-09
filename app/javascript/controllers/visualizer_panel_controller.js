import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]

  connect() {
    this.toggleHandler = () => this.toggle()
    document.addEventListener("visualizer-panel:toggle", this.toggleHandler)
  }

  disconnect() {
    document.removeEventListener("visualizer-panel:toggle", this.toggleHandler)
  }

  toggle() {
    if (this.hasPanelTarget) {
      const isHidden = this.panelTarget.classList.contains("translate-y-full")
      this.panelTarget.classList.toggle("translate-y-full")
      this.panelTarget.classList.toggle("translate-y-0")

      document.dispatchEvent(new CustomEvent("visualizer-panel:visibilityChanged", {
        detail: { visible: isHidden }
      }))
    }
  }

  close() {
    if (this.hasPanelTarget && this.panelTarget.classList.contains("translate-y-0")) {
      this.panelTarget.classList.remove("translate-y-0")
      this.panelTarget.classList.add("translate-y-full")

      document.dispatchEvent(new CustomEvent("visualizer-panel:visibilityChanged", {
        detail: { visible: false }
      }))
    }
  }
}
