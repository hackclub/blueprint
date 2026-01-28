import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input", "error"];
  static values = {
    channelId: { type: String, default: "C09SJ2R1002" },
  };

  connect() {
    this.validate();
  }

  validate() {
    const value = this.inputTarget.value.trim();
    const pattern = new RegExp(
      `^https://hackclub\\.slack\\.com/archives/${this.channelIdValue}/p\\d+$`
    );

    if (value === "") {
      this.hideError();
      this.inputTarget.classList.remove("border-bp-danger", "border-bp-success");
    } else if (pattern.test(value)) {
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
