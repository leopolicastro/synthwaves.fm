import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "video"

  connect() {
    super.connect()

    this.playNowHandler = (e) => this.handlePlayNow(e)
    this.turboLoadHandler = () => this.scanForNativeVideo()
    this.turboBeforeVisitHandler = () => this.stopNativeVideo()

    document.addEventListener("video:playNow", this.playNowHandler, { capture: true })
    document.addEventListener("turbo:load", this.turboLoadHandler)
    document.addEventListener("turbo:before-visit", this.turboBeforeVisitHandler)

    // Scan immediately in case page already loaded
    this.scanForNativeVideo()
  }

  disconnect() {
    super.disconnect()

    document.removeEventListener("video:playNow", this.playNowHandler, { capture: true })
    document.removeEventListener("turbo:load", this.turboLoadHandler)
    document.removeEventListener("turbo:before-visit", this.turboBeforeVisitHandler)
  }

  handlePlayNow(event) {
    event.stopImmediatePropagation()
    event.preventDefault()
    this.send("playVideo", { video: this.buildNativeVideo(event.detail) })
  }

  scanForNativeVideo() {
    const el = document.querySelector("[data-video-native-type]")
    if (!el) return

    const video = {
      streamURL: el.dataset.videoNativeStreamUrl || "",
      title: el.dataset.videoNativeTitle || "",
      type: el.dataset.videoNativeType,
      id: el.dataset.videoNativeId || "",
      thumbnailURL: el.dataset.videoNativeThumbnailUrl || "",
      duration: parseFloat(el.dataset.videoNativeDuration) || 0,
      isLive: false
    }

    this.send("playVideo", { video })

    // Hide the web <video> element
    const webVideo = el.querySelector("video")
    if (webVideo) webVideo.style.display = "none"
  }

  stopNativeVideo() {
    this.send("stopVideo", {})
  }

  buildNativeVideo(detail) {
    return {
      streamURL: detail.url || "",
      title: detail.name || detail.title || "",
      type: detail.type || "hls_channel",
      id: detail.id || "",
      thumbnailURL: detail.thumbnailURL || "",
      duration: detail.duration || 0,
      isLive: detail.type === "hls_channel"
    }
  }
}
