import { Controller } from "@hotwired/stimulus";

// Controls a hidden file input, shows a styled button and filename text
export default class extends Controller {
  static targets = ["input", "filename"];

  connect() {
    this.update();
  }

  trigger() {
    if (this.hasInputTarget) {
      this.inputTarget.click();
    }
  }

  update() {
    if (!this.hasInputTarget || !this.hasFilenameTarget) return;
    const files = this.inputTarget.files;
    const placeholder =
      this.filenameTarget.dataset.placeholder || "No file selected";
    this.filenameTarget.textContent =
      files && files.length > 0
        ? Array.from(files)
            .map((f) => f.name)
            .join(", ")
        : placeholder;
  }
}
