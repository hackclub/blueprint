import { Controller } from "@hotwired/stimulus";

// Previews an image file input
export default class extends Controller {
  static targets = ["input", "preview", "placeholder", "filename", "button"];

  connect() {
    this.updateFilename();
    // Ensure input is accessible and enabled even if wrapped in field_with_errors
    if (this.hasInputTarget) {
      const actualInput =
        this.inputTarget.querySelector('input[type="file"]') ||
        this.inputTarget;
      if (actualInput !== this.inputTarget) {
        this.inputTarget = actualInput;
      }
      // Re-enable input if it was disabled by direct upload
      this.inputTarget.disabled = false;
    }
  }

  trigger() {
    if (this.hasInputTarget) {
      const actualInput =
        this.inputTarget.querySelector('input[type="file"]') ||
        this.inputTarget;
      // Ensure it's enabled before clicking
      actualInput.disabled = false;
      actualInput.click();
    }
  }

  preview() {
    if (!this.hasInputTarget) return;

    const actualInput =
      this.inputTarget.querySelector('input[type="file"]') || this.inputTarget;
    const file = actualInput.files?.[0];

    if (file) {
      // Update preview image
      if (this.hasPreviewTarget) {
        const reader = new FileReader();
        reader.onload = (e) => {
          this.previewTarget.src = e.target.result;
          this.previewTarget.classList.remove("hidden");
        };
        reader.readAsDataURL(file);
      }

      // Hide placeholder
      if (this.hasPlaceholderTarget) {
        this.placeholderTarget.classList.add("hidden");
      }

      // Update button text
      if (this.hasButtonTarget) {
        this.buttonTarget.textContent = "Replace image";
      }

      // Update filename
      this.updateFilename();
    }
  }

  updateFilename() {
    if (!this.hasFilenameTarget || !this.hasInputTarget) return;

    const actualInput =
      this.inputTarget.querySelector('input[type="file"]') || this.inputTarget;
    const files = actualInput.files;
    const placeholder =
      this.filenameTarget.dataset.placeholder || "No file selected";

    this.filenameTarget.textContent =
      files?.length > 0 ? files[0].name : placeholder;
  }
}
