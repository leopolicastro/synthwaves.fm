import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "list"]

  connect() {
    this.toggleHandler = () => this.toggle()
    this.changedHandler = (e) => this.onQueueChanged(e.detail)

    document.addEventListener("queue-panel:toggle", this.toggleHandler)
    document.addEventListener("queue:changed", this.changedHandler)

    this.render()
  }

  disconnect() {
    document.removeEventListener("queue-panel:toggle", this.toggleHandler)
    document.removeEventListener("queue:changed", this.changedHandler)
  }

  toggle() {
    if (this.hasPanelTarget) {
      this.panelTarget.classList.toggle("translate-x-full")
      this.panelTarget.classList.toggle("translate-x-0")
    }
  }

  onQueueChanged({ queue, currentIndex }) {
    this.renderQueue(queue, currentIndex)
  }

  render() {
    const queue = JSON.parse(localStorage.getItem("playerQueue") || "[]")
    const currentIndex = parseInt(localStorage.getItem("playerQueueIndex") || "0")
    this.renderQueue(queue, currentIndex)
  }

  renderQueue(queue, currentIndex) {
    if (!this.hasListTarget) return

    if (queue.length === 0) {
      this.listTarget.innerHTML = `
        <div class="p-8 text-center text-gray-400 text-sm">
          Queue is empty
        </div>
      `
      return
    }

    this.listTarget.innerHTML = queue.map((track, index) => {
      const isCurrent = index === currentIndex
      const bgClass = isCurrent ? "bg-neon-cyan/10" : ""
      const titleClass = isCurrent ? "text-neon-cyan font-semibold" : "text-white"

      return `
        <div class="flex items-center gap-2 px-3 py-2 hover:bg-gray-700 ${bgClass}">
          <button type="button" data-action="click->queue-panel#playAt" data-index="${index}"
                  class="flex-1 min-w-0 text-left cursor-pointer">
            <div class="text-sm ${titleClass} truncate">${this.escapeHtml(track.title || "Unknown")}</div>
            <div class="text-xs text-gray-400 truncate">${this.escapeHtml(track.artist || "")}</div>
          </button>
          <div class="flex items-center gap-0.5 flex-shrink-0">
            ${index > 0 ? `
              <button type="button" data-action="click->queue-panel#moveUp" data-index="${index}"
                      class="p-1 text-gray-400 hover:text-neon-cyan" title="Move up">
                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7"/></svg>
              </button>
            ` : '<div class="w-[26px]"></div>'}
            ${index < queue.length - 1 ? `
              <button type="button" data-action="click->queue-panel#moveDown" data-index="${index}"
                      class="p-1 text-gray-400 hover:text-neon-cyan" title="Move down">
                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/></svg>
              </button>
            ` : '<div class="w-[26px]"></div>'}
            <button type="button" data-action="click->queue-panel#removeAt" data-index="${index}"
                    class="p-1 text-gray-400 hover:text-red-500" title="Remove">
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/></svg>
            </button>
          </div>
        </div>
      `
    }).join("")
  }

  playAt(event) {
    const index = parseInt(event.currentTarget.dataset.index)
    document.dispatchEvent(new CustomEvent("queue:playIndex", {
      detail: { index }
    }))
  }

  moveUp(event) {
    event.stopPropagation()
    const index = parseInt(event.currentTarget.dataset.index)
    document.dispatchEvent(new CustomEvent("queue:moveItem", {
      detail: { from: index, to: index - 1 }
    }))
  }

  moveDown(event) {
    event.stopPropagation()
    const index = parseInt(event.currentTarget.dataset.index)
    document.dispatchEvent(new CustomEvent("queue:moveItem", {
      detail: { from: index, to: index + 1 }
    }))
  }

  removeAt(event) {
    event.stopPropagation()
    const index = parseInt(event.currentTarget.dataset.index)
    document.dispatchEvent(new CustomEvent("queue:removeAt", {
      detail: { index }
    }))
  }

  clear() {
    document.dispatchEvent(new CustomEvent("queue:clear"))
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
