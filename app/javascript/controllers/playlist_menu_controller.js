import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "input", "item", "emptyMessage"]

  toggle(event) {
    event.stopPropagation()
    this.menuTarget.classList.toggle("hidden")

    if (!this.menuTarget.classList.contains("hidden")) {
      this.resetFilter()
    }
  }

  close(event) {
    if (this.element.contains(event.target)) return
    this.menuTarget.classList.add("hidden")
  }

  filter() {
    const query = this.inputTarget.value.toLowerCase()
    let visibleCount = 0

    this.itemTargets.forEach(item => {
      const name = (item.dataset.playlistName || "").toLowerCase()
      const match = name.includes(query)
      item.style.display = match ? "" : "none"
      if (match) visibleCount++
    })

    if (this.hasEmptyMessageTarget) {
      this.emptyMessageTarget.style.display = visibleCount === 0 ? "" : "none"
    }
  }

  filterKeydown(event) {
    if (event.key === "Escape") {
      this.menuTarget.classList.add("hidden")
    }
  }

  resetFilter() {
    if (this.hasInputTarget) {
      this.inputTarget.value = ""
      this.inputTarget.focus()
    }

    this.itemTargets.forEach(item => {
      item.style.display = ""
    })

    if (this.hasEmptyMessageTarget) {
      this.emptyMessageTarget.style.display = "none"
    }
  }
}
