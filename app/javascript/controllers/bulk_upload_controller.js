import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "preview", "list"]

  filesChanged() {
    const files = this.inputTarget.files
    if (files.length === 0) {
      this.previewTarget.classList.add("hidden")
      return
    }

    this.previewTarget.classList.remove("hidden")
    this.listTarget.innerHTML = ""

    Array.from(files).forEach(file => {
      const li = document.createElement("li")
      const size = this.formatSize(file.size)
      li.textContent = `${file.name} (${size})`
      this.listTarget.appendChild(li)
    })
  }

  formatSize(bytes) {
    if (bytes < 1024) return `${bytes} B`
    if (bytes < 1048576) return `${(bytes / 1024).toFixed(1)} KB`
    if (bytes < 1073741824) return `${(bytes / 1048576).toFixed(1)} MB`
    return `${(bytes / 1073741824).toFixed(1)} GB`
  }
}
