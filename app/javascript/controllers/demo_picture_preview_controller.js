import { Controller } from "@hotwired/stimulus";

// Explicit identifier: use data-controller="demo-picture-preview" in views.
export default class DemoPicturePreviewController extends Controller {
  static targets = ["input", "preview", "placeholder"];

  connect() {
    // No-op; waiting for user interaction
  }

  changed() {
    if (!this.hasInputTarget) return;
    const file = this.inputTarget.files && this.inputTarget.files[0];
    if (!file) return;

    // Create an object URL for quick preview
    const url = URL.createObjectURL(file);

    // If we already have an <img>, update src; else create it
    let img;
    if (this.hasPreviewTarget) {
      img = this.previewTarget;
      img.src = url;
      img.classList.remove("hidden");
    } else {
      img = document.createElement("img");
      img.src = url;
      img.className =
        "rounded border border-bp-muted/40 max-h-64 object-contain";
      // Insert before the placeholder span if present or at end
      if (this.hasPlaceholderTarget) {
        this.placeholderTarget.parentElement.insertBefore(
          img,
          this.placeholderTarget
        );
      } else {
        this.element.appendChild(img);
      }
    }

    // Hide placeholder text if we have one
    if (this.hasPlaceholderTarget) {
      this.placeholderTarget.classList.add("hidden");
    }

    // Revoke previous object URL after image loads to free memory
    img.onload = () => {
      URL.revokeObjectURL(url);
    };
  }
}
