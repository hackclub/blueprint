import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle", "button"]

  submit(event) {
    this.buttonTarget.classList.add("opacity-50", "pointer-events-none")
    this.toggleTarget.classList.toggle("bg-green-500")
    this.toggleTarget.classList.toggle("bg-bp-darker")
    this.toggleTarget.classList.toggle("justify-end")
  }
}
