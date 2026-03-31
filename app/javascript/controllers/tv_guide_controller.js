import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["grid", "timeMarker", "timeRange", "timeSlot"]
  static values = {
    windowStart: Number,
    windowEnd: Number,
    pixelsPerMinute: { type: Number, default: 7 }
  }

  connect() {
    this.localizeTimeDisplays()
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

  localizeTimeDisplays() {
    if (this.hasTimeRangeTarget) {
      const el = this.timeRangeTarget
      const start = parseInt(el.dataset.startTimestamp, 10)
      const end = parseInt(el.dataset.endTimestamp, 10)
      if (start && end) {
        el.textContent = `${this.formatTime(start)} \u2013 ${this.formatTime(end, { includeTimeZone: true })}`
      }
    }

    this.timeSlotTargets.forEach(el => {
      const ts = parseInt(el.dataset.timestamp, 10)
      if (ts) el.textContent = this.formatTime(ts)
    })
  }

  formatTime(unixSeconds, { includeTimeZone = false } = {}) {
    const date = new Date(unixSeconds * 1000)
    const options = { hour: "numeric", minute: "2-digit" }
    if (includeTimeZone) options.timeZoneName = "short"
    return new Intl.DateTimeFormat(undefined, options).format(date)
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
