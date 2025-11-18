import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = {
    delay: { type: Number, default: 2000 },
    duration: { type: Number, default: 200 },
    type: { type: String, default: "opacity" },
  };

  connect() {
    setTimeout(() => {
      this.dismiss();
    }, this.delayValue);
  }

  dismiss() {
    if (this.typeValue === "opacity") {
      this.element.style.transition = `opacity ${this.durationValue}ms`;
      this.element.style.opacity = "0";
      setTimeout(() => this.element.remove(), this.durationValue);
    }
  }
}
