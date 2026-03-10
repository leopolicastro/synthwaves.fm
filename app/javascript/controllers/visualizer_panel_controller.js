import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]

  connect() {
    this._airplayActive = false

    this.toggleHandler = () => this.toggle()
    document.addEventListener("visualizer-panel:toggle", this.toggleHandler)

    this.closeHandler = () => this.close()
    document.addEventListener("visualizer-panel:close", this.closeHandler)

    this.airplayHandler = (e) => this._onAirplayStateChanged(e.detail)
    document.addEventListener("airplay:stateChanged", this.airplayHandler)
  }

  disconnect() {
    document.removeEventListener("visualizer-panel:toggle", this.toggleHandler)
    document.removeEventListener("visualizer-panel:close", this.closeHandler)
    document.removeEventListener("airplay:stateChanged", this.airplayHandler)
  }

  toggle() {
    if (this._airplayActive) return

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

  _onAirplayStateChanged({ active }) {
    this._airplayActive = active
  }
}
