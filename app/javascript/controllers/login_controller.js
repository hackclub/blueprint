import { Controller } from "@hotwired/stimulus"

export default class extends Controller {

    static values = {email: String}
    static targets = ["submit"]

    connect() {
        if (this.hasEmailValue && this.emailValue.length > 0 && this.hasSubmitTarget) {
            this.submitTarget.click()
        }
    }
}