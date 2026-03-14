import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]
  static values = { open: Boolean }

  connect() {
    if (this.openValue) this.show()
  }

  show() {
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.classList.add("modal-closing")
    this.dialogTarget.addEventListener("transitionend", () => {
      this.dialogTarget.classList.remove("modal-closing")
      this.dialogTarget.close()
    }, { once: true })
  }

  backdropClick(event) {
    if (event.target === this.dialogTarget) {
      this.close()
    }
  }
}
