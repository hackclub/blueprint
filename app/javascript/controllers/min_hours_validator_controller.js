import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input", "error"];
  static values = {
    min: { type: Number, default: 0.5 },
  };

  connect() {
    this.validate();
  }

  validate() {
    const value = this.inputTarget.value.trim();
    const numValue = parseFloat(value);

    if (value === "") {
      this.hideError();
      this.inputTarget.classList.remove("border-bp-danger", "border-bp-success");
    } else if (!isNaN(numValue) && numValue >= this.minValue) {
      this.hideError();
      this.inputTarget.classList.remove("border-bp-danger");
      this.inputTarget.classList.add("border-bp-success");
    } else {
      this.showError();
      this.inputTarget.classList.remove("border-bp-success");
      this.inputTarget.classList.add("border-bp-danger");
    }
  }

  showError() {
    if (this.hasErrorTarget) {
      this.errorTarget.classList.remove("hidden");
    }
  }

  hideError() {
    if (this.hasErrorTarget) {
      this.errorTarget.classList.add("hidden");
    }
  }
}
