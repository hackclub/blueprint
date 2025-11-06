import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["link", "submitButton"]

  connect() {
    this.disableSubmit()
  }

  trackClick() {
    this.enableSubmit()
  }

  disableSubmit() {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
    }
  }

  enableSubmit() {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = false
    }
  }
}
