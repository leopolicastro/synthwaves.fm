import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["grid", "timeMarker", "timeLabel"]
  static values = {
    windowStart: Number,
    windowEnd: Number,
    pixelsPerMinute: { type: Number, default: 7 }
  }

  connect() {
    this.updateTimeMarker()
    this.markerInterval = setInterval(() => this.updateTimeMarker(), 60000)
    this.scrollToNow()
  }

  disconnect() {
    if (this.markerInterval) clearInterval(this.markerInterval)
  }

  scrollToNow() {
    const now = Date.now() / 1000
    if (now < this.windowStartValue || now > this.windowEndValue) return

    const minutesFromStart = (now - this.windowStartValue) / 60
    const scrollPosition = minutesFromStart * this.pixelsPerMinuteValue

    if (this.hasGridTarget) {
      // Center the current time in the viewport
      const viewportWidth = this.gridTarget.clientWidth
      this.gridTarget.scrollLeft = Math.max(0, scrollPosition - viewportWidth / 3)
    }
  }

  jumpToNow() {
    this.scrollToNow()
  }

  navigateBack() {
    this.navigateByMinutes(-30)
  }

  navigateForward() {
    this.navigateByMinutes(30)
  }

  navigateByMinutes(minutes) {
    if (this.hasGridTarget) {
      this.gridTarget.scrollLeft += minutes * this.pixelsPerMinuteValue
    }
  }

  updateTimeMarker() {
    if (!this.hasTimeMarkerTarget) return

    const now = Date.now() / 1000
    if (now < this.windowStartValue || now > this.windowEndValue) {
      this.timeMarkerTarget.style.display = "none"
      return
    }

    const minutesFromStart = (now - this.windowStartValue) / 60
    const position = minutesFromStart * this.pixelsPerMinuteValue

    this.timeMarkerTarget.style.display = "block"
    this.timeMarkerTarget.style.left = `${position}px`
  }
}
