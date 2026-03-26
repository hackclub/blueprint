import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["feedbackTextarea", "reasonTextarea", "feedbackCheckbox", "reasonCheckbox", "approveButton", "hoursOverride"]
  static values = { ysws: String }

  connect() {
    this.handleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.handleKeydown)
    this.autofillHours()
  }

  autofillHours() {
    if (!this.hasHoursOverrideTarget) return
    const hours = { hackpad: 15, squeak: 5, led: 5 }
    const value = hours[this.yswsValue]
    if (value) {
      this.hoursOverrideTarget.value = value
      this.hoursOverrideTarget.dispatchEvent(new Event("input", { bubbles: true }))
    }
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown)
  }

  handleKeydown(event) {
    if (event.ctrlKey && event.key === "Enter" && this.hasApproveButtonTarget) {
      event.preventDefault()
      this.approveButtonTarget.click()
    }
  }

  updateFeedback() {
    const texts = this.feedbackCheckboxTargets
      .filter(cb => cb.checked)
      .map(cb => cb.dataset.text)
    this.feedbackTextareaTarget.value = texts.join("\n\n")
  }

  updateReason() {
    const texts = this.reasonCheckboxTargets
      .filter(cb => cb.checked)
      .map(cb => cb.dataset.text)
    this.reasonTextareaTarget.value = texts.join("\n\n")
  }

  submitForm() {
    if (this.hasFeedbackTextareaTarget) {
      const feedback = this.feedbackTextareaTarget
      if (feedback.value.trim() === "") {
        feedback.value = "Awesome project!"
      }
    }
  }
}
