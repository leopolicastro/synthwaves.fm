import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { pageKey: String }
  static targets = ["container", "gridBtn", "listBtn"]

  connect() {
    this.applyMode(this.currentMode)
  }

  containerTargetConnected() {
    this.applyMode(this.currentMode)
  }

  setGrid() {
    this.saveAndApply("grid")
  }

  setList() {
    this.saveAndApply("list")
  }

  get storageKey() {
    return `viewMode:${this.pageKeyValue}`
  }

  get currentMode() {
    const saved = localStorage.getItem(this.storageKey)
    if (saved) return saved

    return window.matchMedia("(min-width: 768px)").matches ? "grid" : "list"
  }

  saveAndApply(mode) {
    localStorage.setItem(this.storageKey, mode)
    this.applyMode(mode)
  }

  applyMode(mode) {
    if (this.hasContainerTarget) {
      this.containerTarget.dataset.viewMode = mode
    }

    if (this.hasGridBtnTarget && this.hasListBtnTarget) {
      this.gridBtnTarget.classList.toggle("bg-gray-700", mode === "grid")
      this.gridBtnTarget.classList.toggle("text-neon-cyan", mode === "grid")
      this.gridBtnTarget.classList.toggle("text-gray-400", mode !== "grid")

      this.listBtnTarget.classList.toggle("bg-gray-700", mode === "list")
      this.listBtnTarget.classList.toggle("text-neon-cyan", mode === "list")
      this.listBtnTarget.classList.toggle("text-gray-400", mode !== "list")
    }
  }
}
