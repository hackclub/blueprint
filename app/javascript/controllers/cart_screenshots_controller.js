import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { needsFunding: Boolean, hasExisting: Boolean };
  static targets = ["input", "error", "previews", "nextButton", "filename"];

  connect() {
    this.filesList = [];
    this.updatePreviews();
    this.updateButtonState();
  }

  trigger() {
    this.inputTarget.click();
  }

  filesChanged() {
    this.clearError();

    const newFiles = Array.from(this.inputTarget.files || []);
    newFiles.forEach(file => {
      if (file.type.startsWith("image/")) {
        this.filesList.push(file);
      }
    });

    this.inputTarget.value = "";

    if (this.filesList.length > 0) {
      this.hasExistingValue = true;
    }

    this.updatePreviews();
    this.updateButtonState();
    this.updateFilename();
  }

  updateFilename() {
    if (!this.hasFilenameTarget) return;
    const count = this.filesList.length;
    this.filenameTarget.textContent = count > 0 ? `${count} file${count > 1 ? "s" : ""} selected` : "No files selected";
  }

  updatePreviews() {
    this.previewsTarget.innerHTML = "";

    this.filesList.forEach((file, index) => {
      const container = document.createElement("div");
      container.className = "relative";

      const img = document.createElement("img");
      img.className = "rounded border border-bp-muted/40 object-cover w-full h-32";
      img.src = URL.createObjectURL(file);

      const deleteBtn = document.createElement("button");
      deleteBtn.type = "button";
      deleteBtn.className = "absolute -top-2 -right-2 bg-bp-danger rounded-full size-6 flex items-center justify-center hover:bg-bp-danger/80 transition-colors";
      deleteBtn.innerHTML = '<svg class="size-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>';
      deleteBtn.dataset.index = index;
      deleteBtn.addEventListener("click", () => this.deleteFile(index));

      container.appendChild(img);
      container.appendChild(deleteBtn);
      this.previewsTarget.appendChild(container);
    });

    this.updateFormInput();
  }

  deleteFile(index) {
    this.filesList.splice(index, 1);

    if (this.filesList.length === 0) {
      this.hasExistingValue = false;
    }

    this.updatePreviews();
    this.updateButtonState();
    this.updateFilename();
  }

  updateFormInput() {
    const dataTransfer = new DataTransfer();
    this.filesList.forEach(file => dataTransfer.items.add(file));
    this.inputTarget.files = dataTransfer.files;
  }

  updateButtonState() {
    if (!this.hasNextButtonTarget) return;

    if (this.needsFundingValue && !this.hasAtLeastOneImage()) {
      this.nextButtonTarget.disabled = true;
      this.nextButtonTarget.classList.add("opacity-50", "cursor-not-allowed");
    } else {
      this.nextButtonTarget.disabled = false;
      this.nextButtonTarget.classList.remove("opacity-50", "cursor-not-allowed");
    }
  }

  handleNext(event) {
    if (this.needsFundingValue && !this.hasAtLeastOneImage()) {
      event.preventDefault();
      event.stopPropagation();
      return false;
    }

    const paginateController = this.application.getControllerForElementAndIdentifier(
      document.querySelector('[data-controller*="paginate"]'),
      "paginate"
    );

    if (paginateController) {
      paginateController.next();
    }
  }

  hasAtLeastOneImage() {
    return this.hasExistingValue || (this.inputTarget.files && this.inputTarget.files.length > 0);
  }

  showError(message) {
    this.errorTarget.textContent = message;
    this.errorTarget.classList.remove("hidden");
  }

  clearError() {
    this.errorTarget.textContent = "";
    this.errorTarget.classList.add("hidden");
  }
}
