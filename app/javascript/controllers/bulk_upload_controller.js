import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage"

export default class extends Controller {
  static targets = ["input", "preview", "list", "submit"]

  filesChanged() {
    const files = this.inputTarget.files
    if (files.length === 0) {
      this.previewTarget.classList.add("hidden")
      return
    }

    this.previewTarget.classList.remove("hidden")
    this.listTarget.innerHTML = ""

    Array.from(files).forEach((file, index) => {
      const li = document.createElement("li")
      li.id = `file-${index}`
      li.className = "flex items-center justify-between gap-2"
      li.innerHTML = `
        <span class="truncate">${file.name} (${this.formatSize(file.size)})</span>
        <span class="text-gray-500 text-xs shrink-0" data-status>Pending</span>
      `
      this.listTarget.appendChild(li)
    })
  }

  async submit(event) {
    if (this.uploadsComplete) return

    event.preventDefault()

    const files = Array.from(this.inputTarget.files)
    if (files.length === 0) return

    this.submitTarget.disabled = true
    this.submitTarget.value = `Uploading 0/${files.length}...`
    this.inputTarget.disabled = true

    const { results } = await this.uploadAll(files)

    if (results.length === 0) {
      this.submitTarget.disabled = false
      this.submitTarget.value = "Upload Season"
      this.inputTarget.disabled = false
      return
    }

    this.inputTarget.removeAttribute("name")

    const form = this.element
    results.forEach(({ signedId, filename }) => {
      form.appendChild(this.hiddenInput("signed_blob_ids[]", signedId))
      form.appendChild(this.hiddenInput("filenames[]", filename))
    })

    this.submitTarget.value = "Creating videos..."
    this.uploadsComplete = true
    form.requestSubmit()
  }

  async uploadAll(files) {
    const results = []
    let completed = 0
    let failureCount = 0
    const concurrency = 3
    let nextIndex = 0

    const worker = async () => {
      while (nextIndex < files.length) {
        const i = nextIndex++
        try {
          const result = await this.uploadFile(files[i], i)
          results.push(result)
        } catch (error) {
          failureCount++
          console.error(`Upload failed for ${files[i].name}:`, error)
        }
        completed++
        this.submitTarget.value = `Uploading ${completed}/${files.length}...`
      }
    }

    const workers = Array.from(
      { length: Math.min(concurrency, files.length) },
      () => worker()
    )
    await Promise.all(workers)

    return { results, failureCount }
  }

  uploadFile(file, index) {
    return new Promise((resolve, reject) => {
      const upload = new DirectUpload(file, "/rails/active_storage/direct_uploads", {
        directUploadWillStoreFileWithXHR: (request) => {
          request.upload.addEventListener("progress", (event) => {
            const percent = Math.round((event.loaded / event.total) * 100)
            this.updateStatus(index, `${percent}%`, "text-neon-cyan")
          })
        }
      })

      this.updateStatus(index, "Uploading...", "text-neon-cyan")

      upload.create((error, blob) => {
        if (error) {
          this.updateStatus(index, "Failed", "text-red-400")
          reject(error)
        } else {
          this.updateStatus(index, "Done", "text-green-400")
          resolve({ signedId: blob.signed_id, filename: file.name })
        }
      })
    })
  }

  updateStatus(index, text, colorClass) {
    const li = document.getElementById(`file-${index}`)
    if (!li) return
    const el = li.querySelector("[data-status]")
    if (!el) return
    el.textContent = text
    el.className = `${colorClass} text-xs shrink-0`
  }

  hiddenInput(name, value) {
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = name
    input.value = value
    return input
  }

  formatSize(bytes) {
    if (bytes < 1024) return `${bytes} B`
    if (bytes < 1048576) return `${(bytes / 1024).toFixed(1)} KB`
    if (bytes < 1073741824) return `${(bytes / 1048576).toFixed(1)} MB`
    return `${(bytes / 1073741824).toFixed(1)} GB`
  }
}
