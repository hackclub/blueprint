import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "visual"]

  connect() {
    this.updateVisual()
  }

  toggle() {
    this.updateVisual()
  }

  updateVisual() {
    if (this.checkboxTarget.checked) {
      this.visualTarget.classList.add("checked")
    } else {
      this.visualTarget.classList.remove("checked")
    }
  }
}
