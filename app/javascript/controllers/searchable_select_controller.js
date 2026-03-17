import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select"]

  connect() {
    this.selectTarget.style.display = "none"
    this.createSearchInput()
    this.filterOptions()
  }

  createSearchInput() {
    const wrapper = document.createElement("div")
    wrapper.className = "relative"

    this.input = document.createElement("input")
    this.input.type = "text"
    this.input.placeholder = "Search for a country..."
    this.input.className = "w-full p-3 bg-bp-dark border border-white/25 rounded-sm text-white mb-2"
    this.input.addEventListener("input", () => this.filterOptions())

    wrapper.appendChild(this.input)
    this.element.insertBefore(wrapper, this.selectTarget)
  }

  filterOptions() {
    const filter = this.input.value.toLowerCase()
    Array.from(this.selectTarget.options).forEach(option => {
      const text = option.text.toLowerCase()
      option.hidden = !text.includes(filter)
    })
  }
}
