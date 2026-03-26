import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["youtubeFields", "streamFields"]

  toggle(event) {
    const sourceType = event.target.value

    if (sourceType === "youtube") {
      this.youtubeFieldsTarget.classList.remove("hidden")
      this.streamFieldsTarget.classList.add("hidden")
      this.streamFieldsTarget.querySelectorAll("input").forEach(i => i.value = "")
    } else {
      this.youtubeFieldsTarget.classList.add("hidden")
      this.streamFieldsTarget.classList.remove("hidden")
      this.youtubeFieldsTarget.querySelectorAll("input").forEach(i => i.value = "")
    }
  }

  submit() {
    // Clear hidden fields before submit so stale values don't get sent
    if (this.youtubeFieldsTarget.classList.contains("hidden")) {
      this.youtubeFieldsTarget.querySelectorAll("input").forEach(i => i.value = "")
    }
    if (this.streamFieldsTarget.classList.contains("hidden")) {
      this.streamFieldsTarget.querySelectorAll("input").forEach(i => i.value = "")
    }
  }
}
