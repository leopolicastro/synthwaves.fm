import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.queue = JSON.parse(localStorage.getItem("playerQueue") || "[]")
    this.currentIndex = parseInt(localStorage.getItem("playerQueueIndex") || "0")
    this.repeatMode = localStorage.getItem("playerRepeatMode") || "off"
    this.shuffleEnabled = localStorage.getItem("playerShuffle") === "true"
    this.shuffleOrder = JSON.parse(localStorage.getItem("playerShuffleOrder") || "[]")
    this.shufflePosition = parseInt(localStorage.getItem("playerShufflePosition") || "0")

    this.addHandler = (e) => this.add(e.detail)
    this.playNowHandler = (e) => this.playNow(e.detail)
    this.nextHandler = () => this.next()
    this.previousHandler = () => this.previous()
    this.cycleRepeatHandler = () => this.cycleRepeat()
    this.toggleShuffleHandler = () => this.toggleShuffle()
    this.removeAtHandler = (e) => this.removeAt(e.detail.index)
    this.moveItemHandler = (e) => this.moveItem(e.detail.from, e.detail.to)
    this.playIndexHandler = (e) => this.playIndex(e.detail.index)
    this.clearHandler = () => this.clear()
    this.peekNextHandler = () => this._dispatchNextTrackInfo()

    document.addEventListener("queue:add", this.addHandler)
    document.addEventListener("queue:playNow", this.playNowHandler)
    document.addEventListener("queue:next", this.nextHandler)
    document.addEventListener("queue:previous", this.previousHandler)
    document.addEventListener("queue:cycleRepeat", this.cycleRepeatHandler)
    document.addEventListener("queue:toggleShuffle", this.toggleShuffleHandler)
    document.addEventListener("queue:removeAt", this.removeAtHandler)
    document.addEventListener("queue:moveItem", this.moveItemHandler)
    document.addEventListener("queue:playIndex", this.playIndexHandler)
    document.addEventListener("queue:clear", this.clearHandler)
    document.addEventListener("queue:peekNext", this.peekNextHandler)
  }

  disconnect() {
    document.removeEventListener("queue:add", this.addHandler)
    document.removeEventListener("queue:playNow", this.playNowHandler)
    document.removeEventListener("queue:next", this.nextHandler)
    document.removeEventListener("queue:previous", this.previousHandler)
    document.removeEventListener("queue:cycleRepeat", this.cycleRepeatHandler)
    document.removeEventListener("queue:toggleShuffle", this.toggleShuffleHandler)
    document.removeEventListener("queue:removeAt", this.removeAtHandler)
    document.removeEventListener("queue:moveItem", this.moveItemHandler)
    document.removeEventListener("queue:playIndex", this.playIndexHandler)
    document.removeEventListener("queue:clear", this.clearHandler)
    document.removeEventListener("queue:peekNext", this.peekNextHandler)
  }

  add(track) {
    this.queue.push(track)
    if (this.shuffleEnabled) {
      const insertPos = this.shufflePosition + 1 + Math.floor(Math.random() * (this.shuffleOrder.length - this.shufflePosition))
      this.shuffleOrder.splice(insertPos, 0, this.queue.length - 1)
    }
    this.save()
  }

  playNow(track) {
    const index = this.queue.findIndex(t => t.trackId === track.trackId && t.trackId !== 0)
    if (index >= 0) {
      this.queue[index] = track
      this.currentIndex = index
    } else {
      this.queue.push(track)
      this.currentIndex = this.queue.length - 1
    }
    if (this.shuffleEnabled) {
      this.generateShuffleOrder()
    }
    this.save()
    this.playCurrent()
  }

  next() {
    if (this.shuffleEnabled) {
      if (this.shufflePosition < this.shuffleOrder.length - 1) {
        this.shufflePosition++
        this.currentIndex = this.shuffleOrder[this.shufflePosition]
        this.save()
        this.playCurrent()
      } else if (this.repeatMode === "all") {
        this.generateShuffleOrder()
        this.shufflePosition = 0
        this.currentIndex = this.shuffleOrder[0]
        this.save()
        this.playCurrent()
      }
    } else {
      if (this.currentIndex < this.queue.length - 1) {
        this.currentIndex++
        this.save()
        this.playCurrent()
      } else if (this.repeatMode === "all") {
        this.currentIndex = 0
        this.save()
        this.playCurrent()
      }
    }
  }

  previous() {
    if (this.shuffleEnabled) {
      if (this.shufflePosition > 0) {
        this.shufflePosition--
        this.currentIndex = this.shuffleOrder[this.shufflePosition]
        this.save()
        this.playCurrent()
      }
    } else {
      if (this.currentIndex > 0) {
        this.currentIndex--
        this.save()
        this.playCurrent()
      }
    }
  }

  cycleRepeat() {
    const modes = ["off", "all", "one"]
    const nextIndex = (modes.indexOf(this.repeatMode) + 1) % modes.length
    this.repeatMode = modes[nextIndex]
    localStorage.setItem("playerRepeatMode", this.repeatMode)
    document.dispatchEvent(new CustomEvent("queue:repeatChanged", {
      detail: { mode: this.repeatMode }
    }))
  }

  toggleShuffle() {
    this.shuffleEnabled = !this.shuffleEnabled
    localStorage.setItem("playerShuffle", this.shuffleEnabled.toString())
    if (this.shuffleEnabled) {
      this.generateShuffleOrder()
    } else {
      this.shuffleOrder = []
      this.shufflePosition = 0
    }
    this.saveShuffleState()
    document.dispatchEvent(new CustomEvent("queue:shuffleChanged", {
      detail: { enabled: this.shuffleEnabled }
    }))
  }

  removeAt(index) {
    if (index < 0 || index >= this.queue.length) return
    this.queue.splice(index, 1)
    if (this.shuffleEnabled) {
      this.shuffleOrder = this.shuffleOrder
        .filter(i => i !== index)
        .map(i => i > index ? i - 1 : i)
      if (this.shufflePosition >= this.shuffleOrder.length) {
        this.shufflePosition = Math.max(0, this.shuffleOrder.length - 1)
      }
    }
    if (index < this.currentIndex) {
      this.currentIndex--
    } else if (index === this.currentIndex) {
      if (this.currentIndex >= this.queue.length) {
        this.currentIndex = Math.max(0, this.queue.length - 1)
      }
    }
    this.save()
  }

  moveItem(from, to) {
    if (from < 0 || from >= this.queue.length || to < 0 || to >= this.queue.length) return
    const [item] = this.queue.splice(from, 1)
    this.queue.splice(to, 0, item)
    if (this.currentIndex === from) {
      this.currentIndex = to
    } else if (from < this.currentIndex && to >= this.currentIndex) {
      this.currentIndex--
    } else if (from > this.currentIndex && to <= this.currentIndex) {
      this.currentIndex++
    }
    if (this.shuffleEnabled) {
      this.shuffleOrder = this.shuffleOrder.map(i => {
        if (i === from) return to
        if (from < to) {
          if (i > from && i <= to) return i - 1
        } else {
          if (i >= to && i < from) return i + 1
        }
        return i
      })
    }
    this.save()
  }

  playIndex(index) {
    if (index < 0 || index >= this.queue.length) return
    this.currentIndex = index
    if (this.shuffleEnabled) {
      const pos = this.shuffleOrder.indexOf(index)
      if (pos >= 0) this.shufflePosition = pos
    }
    this.save()
    this.playCurrent()
  }

  clear() {
    this.queue = []
    this.currentIndex = 0
    this.shuffleOrder = []
    this.shufflePosition = 0
    this.save()
  }

  playCurrent() {
    const track = this.queue[this.currentIndex]
    if (track) {
      if (track.youtubeVideoId) {
        document.dispatchEvent(new CustomEvent("player:playYouTube", { detail: track }))
      } else {
        document.dispatchEvent(new CustomEvent("player:play", { detail: track }))
      }
    }
  }

  peekNext() {
    if (this.shuffleEnabled) {
      if (this.shufflePosition < this.shuffleOrder.length - 1) {
        return this.queue[this.shuffleOrder[this.shufflePosition + 1]] || null
      } else if (this.repeatMode === "all" && this.queue.length > 0) {
        return this.queue[0] || null
      }
    } else {
      if (this.currentIndex < this.queue.length - 1) {
        return this.queue[this.currentIndex + 1] || null
      } else if (this.repeatMode === "all" && this.queue.length > 0) {
        return this.queue[0] || null
      }
    }
    return null
  }

  _dispatchNextTrackInfo() {
    const next = this.peekNext()
    document.dispatchEvent(new CustomEvent("queue:nextTrackInfo", {
      detail: { track: next }
    }))
  }

  generateShuffleOrder() {
    const indices = Array.from({ length: this.queue.length }, (_, i) => i)
    const currentPos = indices.indexOf(this.currentIndex)
    if (currentPos > 0) {
      [indices[0], indices[currentPos]] = [indices[currentPos], indices[0]]
    }
    // Fisher-Yates shuffle from index 1 onwards
    for (let i = indices.length - 1; i > 1; i--) {
      const j = 1 + Math.floor(Math.random() * i)
      ;[indices[i], indices[j]] = [indices[j], indices[i]]
    }
    this.shuffleOrder = indices
    this.shufflePosition = 0
  }

  save() {
    localStorage.setItem("playerQueue", JSON.stringify(this.queue))
    localStorage.setItem("playerQueueIndex", this.currentIndex.toString())
    this.saveShuffleState()
    document.dispatchEvent(new CustomEvent("queue:changed", {
      detail: {
        queue: this.queue,
        currentIndex: this.currentIndex,
        shuffleEnabled: this.shuffleEnabled,
        shuffleOrder: this.shuffleOrder,
        shufflePosition: this.shufflePosition
      }
    }))
    this._dispatchNextTrackInfo()
  }

  saveShuffleState() {
    localStorage.setItem("playerShuffleOrder", JSON.stringify(this.shuffleOrder))
    localStorage.setItem("playerShufflePosition", this.shufflePosition.toString())
  }
}
