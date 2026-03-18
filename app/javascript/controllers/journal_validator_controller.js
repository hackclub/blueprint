import { Controller } from "@hotwired/stimulus";

// data-controller="journal-validator"
// Enforces a minimum character count (excluding image markdown), a minimum image count,
// and a positive hour count.
// Configure via data values:
//   data-journal-validator-min-chars-value="100"
//   data-journal-validator-image-required-value="true"
export default class extends Controller {
  static values = {
    minChars: { type: Number, default: 100 },
    imageRequired: { type: Boolean, default: true },
  };
  static targets = ["charCount", "imageCount", "summaryCount", "textarea", "summary", "hours", "submit"];

  connect() {
    this._onInput = this.onInput.bind(this);

    // Attach to content input (Stimulus target or Marksmith textarea)
    const inputEl = this.inputElement;
    if (inputEl) {
      inputEl.addEventListener("input", this._onInput);
      inputEl.addEventListener("change", this._onInput);
      inputEl.addEventListener("keyup", this._onInput);
      this._boundInputEl = inputEl;
    }

    if (this.hasSummaryTarget) {
      this.summaryTarget.addEventListener("input", this._onInput);
      this.summaryTarget.addEventListener("change", this._onInput);
    }

    if (this.hasHoursTarget) {
      this.hoursTarget.addEventListener("input", this._onInput);
      this.hoursTarget.addEventListener("change", this._onInput);
    }

    // Fallback: poll for programmatic changes after uploads/insertions and late-mounted inputs
    this._lastValue = inputEl ? inputEl.value || "" : "";
    this._poll = setInterval(() => {
      const el = this.inputElement;

      // If the input element appeared or changed, (re)bind listeners
      if (el && el !== this._boundInputEl) {
        if (this._boundInputEl) {
          this._boundInputEl.removeEventListener("input", this._onInput);
          this._boundInputEl.removeEventListener("change", this._onInput);
          this._boundInputEl.removeEventListener("keyup", this._onInput);
        }
        el.addEventListener("input", this._onInput);
        el.addEventListener("change", this._onInput);
        el.addEventListener("keyup", this._onInput);
        this._boundInputEl = el;
        this._lastValue = el.value || "";
        this.onInput();
        return;
      }

      if (el && el.value !== this._lastValue) {
        this._lastValue = el.value;
        this.onInput();
      }
    }, 300);

    // Initial compute
    this.onInput();
  }

  disconnect() {
    if (this._boundInputEl && this._onInput) {
      this._boundInputEl.removeEventListener("input", this._onInput);
      this._boundInputEl.removeEventListener("change", this._onInput);
      this._boundInputEl.removeEventListener("keyup", this._onInput);
    }
    if (this.hasSummaryTarget && this._onInput) {
      this.summaryTarget.removeEventListener("input", this._onInput);
      this.summaryTarget.removeEventListener("change", this._onInput);
    }
    if (this.hasHoursTarget && this._onInput) {
      this.hoursTarget.removeEventListener("input", this._onInput);
      this.hoursTarget.removeEventListener("change", this._onInput);
    }
    if (this._poll) clearInterval(this._poll);
  }

  get inputElement() {
    if (this.hasTextareaTarget) return this.textareaTarget;
    return this.element.querySelector(".marksmith-textarea, textarea");
  }

  onInput() {
    const el = this.inputElement;
    const content = el ? el.value || "" : "";
    const imageRegex = /!\[[^\]]*\]\([^)]+\)/g;

    const imageMatches = content.match(imageRegex) || [];
    const withoutImages = content.replace(imageRegex, "");

    // Normalize for character count: strip leading/trailing spaces per line and remove newlines
    const normalized = withoutImages
      .split(/\r?\n/)
      .map((line) => line.trim())
      .join("");

    const chars = normalized.length;
    const images = imageMatches.length;

    // Hours validation (> 0, any number of decimal places)
    const hoursRaw = this.hasHoursTarget ? (this.hoursTarget.value || "") : "";
    const hoursValue = this.hasHoursTarget ? Number(hoursRaw) : NaN;
    const okHours = this.hasHoursTarget
      ? Number.isFinite(hoursValue) && hoursValue > 0 && hoursValue < 1000
      : true;

    // Summary validation (required, <= 60 chars)
    const summary = this.hasSummaryTarget ? (this.summaryTarget.value || "") : "";
    const summaryLen = summary.length;
    const okSummary = this.hasSummaryTarget ? summaryLen > 0 && summaryLen <= 60 : true;

       // Update UI
    if (this.hasCharCountTarget)
      this.charCountTarget.textContent = `${chars}/${this.minCharsValue}`;
    if (this.hasImageCountTarget)
      this.imageCountTarget.textContent = `${images}/1`;
       if (this.hasSummaryCountTarget)
      this.summaryCountTarget.textContent = `${summaryLen}/60`;
    
    // Toggle submit availability
       const okChars = chars >= this.minCharsValue;
    const okImages = this.imageRequiredValue ? images >= 1 : true;
    const valid = okChars && okImages && okHours && okSummary;
    
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = !valid;
    }
 
    // Optionally add classes to the counters
    this.toggleStateClass(this.charCountTarget, okChars);
    this.toggleStateClass(this.imageCountTarget, okImages);
    this.toggleStateClass(this.summaryCountTarget, okSummary);
  }

  toggleStateClass(el, ok) {
    if (!el) return;
    el.classList.toggle("text-bp-success", ok);
    el.classList.toggle("text-bp-danger", !ok);
  }
}
