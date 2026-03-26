import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["feedbackTextarea", "reasonTextarea", "feedbackCheckbox", "reasonCheckbox", "approveButton"]

  connect() {
    this.handleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.handleKeydown)
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
