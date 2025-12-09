import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "warning"]

  validate() {
    const birthday = new Date(this.inputTarget.value)
    if (isNaN(birthday)) {
      this.warningTarget.classList.add("hidden")
      return
    }

    const today = new Date()
    const age = Math.floor((today - birthday) / (365.25 * 24 * 60 * 60 * 1000))

    if (age < 8 || age > 80) {
      this.warningTarget.classList.remove("hidden")
    } else {
      this.warningTarget.classList.add("hidden")
    }
  }
}
