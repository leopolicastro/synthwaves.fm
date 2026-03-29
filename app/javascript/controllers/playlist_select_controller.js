import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["newNameField", "section"]

  changed() {
    this.newNameFieldTarget.classList.toggle("hidden", this.selectValue !== "new")
  }

  mediaTypeChanged(event) {
    this.sectionTarget.classList.toggle("hidden", event.target.value === "video")
  }

  get selectValue() {
    return this.element.querySelector("select").value
  }
}
