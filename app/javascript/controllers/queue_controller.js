import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.queue = JSON.parse(localStorage.getItem("playerQueue") || "[]")
    this.currentIndex = parseInt(localStorage.getItem("playerQueueIndex") || "0")

    this.addHandler = (e) => this.add(e.detail)
    this.playNowHandler = (e) => this.playNow(e.detail)
    this.nextHandler = () => this.next()
    this.previousHandler = () => this.previous()

    document.addEventListener("queue:add", this.addHandler)
    document.addEventListener("queue:playNow", this.playNowHandler)
    document.addEventListener("queue:next", this.nextHandler)
    document.addEventListener("queue:previous", this.previousHandler)
  }

  disconnect() {
    document.removeEventListener("queue:add", this.addHandler)
    document.removeEventListener("queue:playNow", this.playNowHandler)
    document.removeEventListener("queue:next", this.nextHandler)
    document.removeEventListener("queue:previous", this.previousHandler)
  }

  add(track) {
    this.queue.push(track)
    this.save()
  }

  playNow(track) {
    const index = this.queue.findIndex(t => t.trackId === track.trackId)
    if (index >= 0) {
      this.currentIndex = index
    } else {
      this.queue.push(track)
      this.currentIndex = this.queue.length - 1
    }
    this.save()
    this.playCurrent()
  }

  next() {
    if (this.currentIndex < this.queue.length - 1) {
      this.currentIndex++
      this.save()
      this.playCurrent()
    }
  }

  previous() {
    if (this.currentIndex > 0) {
      this.currentIndex--
      this.save()
      this.playCurrent()
    }
  }

  playCurrent() {
    const track = this.queue[this.currentIndex]
    if (track) {
      document.dispatchEvent(new CustomEvent("player:play", { detail: track }))
    }
  }

  save() {
    localStorage.setItem("playerQueue", JSON.stringify(this.queue))
    localStorage.setItem("playerQueueIndex", this.currentIndex.toString())
  }
}
