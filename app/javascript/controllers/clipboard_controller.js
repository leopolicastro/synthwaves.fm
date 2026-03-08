import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { content: String }
  static targets = ["button"]

  async copy() {
    await navigator.clipboard.writeText(this.contentValue)

    const button = this.buttonTarget
    const originalText = button.textContent
    button.textContent = "Copied!"

    setTimeout(() => {
      button.textContent = originalText
    }, 2000)
  }
}
