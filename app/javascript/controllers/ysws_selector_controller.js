import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["option", "field", "defaultText", "hackpadText"]

  connect() {
    if (this.hasOptionTarget) {
      this.optionTargets.forEach(option => {
        option.classList.add("border-bp-darker")
        option.classList.remove("border-white")
      })

      const hackpadOption = this.optionTargets.find(option => option.dataset.value === "hackpad")
      if (hackpadOption) {
        hackpadOption.classList.remove("border-bp-darker")
        hackpadOption.classList.add("border-white")
        this.fieldTarget.value = "hackpad"
      }
    }

    this.updateText()
  }

  select(event) {
    const selectedOption = event.currentTarget
    const value = selectedOption.dataset.value

    this.optionTargets.forEach(option => {
      option.classList.add("border-bp-darker")
      option.classList.remove("border-white")
    })

    selectedOption.classList.remove("border-bp-darker")
    selectedOption.classList.add("border-white")

    this.fieldTarget.value = value
    this.updateText()
  }

  updateText() {
    if (!this.hasDefaultTextTarget || !this.hasHackpadTextTarget) return
    if (!this.hasFieldTarget) return

    if (this.fieldTarget.value === "hackpad") {
      this.defaultTextTargets.forEach(el => el.classList.add("hidden"))
      this.hackpadTextTargets.forEach(el => el.classList.remove("hidden"))
    } else {
      this.defaultTextTargets.forEach(el => el.classList.remove("hidden"))
      this.hackpadTextTargets.forEach(el => el.classList.add("hidden"))
    }
  }
}
