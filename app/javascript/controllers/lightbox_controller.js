import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="lightbox"
export default class extends Controller {
  static targets = ["modal", "image", "counter"]
  static values = {
    images: Array,
    currentIndex: { type: Number, default: 0 }
  }

  connect() {
    // Bind keyboard events
    this.boundHandleKeydown = this.handleKeydown.bind(this)
  }

  disconnect() {
    document.removeEventListener('keydown', this.boundHandleKeydown)
  }

  open(event) {
    event.preventDefault()
    const index = parseInt(event.currentTarget.dataset.index)
    this.currentIndexValue = index

    this.updateImage()
    this.modalTarget.classList.remove('hidden')
    document.body.style.overflow = 'hidden'

    // Add keyboard listener
    document.addEventListener('keydown', this.boundHandleKeydown)
  }

  close(event) {
    if (event) event.preventDefault()
    this.modalTarget.classList.add('hidden')
    document.body.style.overflow = 'auto'

    // Remove keyboard listener
    document.removeEventListener('keydown', this.boundHandleKeydown)
  }

  previous(event) {
    event.preventDefault()
    event.stopPropagation()

    if (this.currentIndexValue > 0) {
      this.currentIndexValue--
      this.updateImage()
    }
  }

  next(event) {
    event.preventDefault()
    event.stopPropagation()

    if (this.currentIndexValue < this.imagesValue.length - 1) {
      this.currentIndexValue++
      this.updateImage()
    }
  }

  handleKeydown(event) {
    switch(event.key) {
      case 'Escape':
        this.close()
        break
      case 'ArrowLeft':
        if (this.currentIndexValue > 0) {
          this.currentIndexValue--
          this.updateImage()
        }
        break
      case 'ArrowRight':
        if (this.currentIndexValue < this.imagesValue.length - 1) {
          this.currentIndexValue++
          this.updateImage()
        }
        break
    }
  }

  updateImage() {
    const currentImage = this.imagesValue[this.currentIndexValue]
    this.imageTarget.src = currentImage
    this.counterTarget.textContent = `${this.currentIndexValue + 1} / ${this.imagesValue.length}`
  }

  // Close when clicking backdrop
  closeOnBackdrop(event) {
    if (event.target === event.currentTarget) {
      this.close()
    }
  }
}
