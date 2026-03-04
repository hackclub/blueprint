import { Controller } from "@hotwired/stimulus"

// Handles "show more / show less" for overflow-truncated text blocks.
// Usage:
//   data-controller="text-expander"
//   data-text-expander-target="content"  (the overflowing element)
//   data-text-expander-target="toggle"   (the button)
//   data-action="click->text-expander#toggle"
export default class extends Controller {
  static targets = ["content", "toggle"]

  connect() {
    if (this.hasContentTarget && this.hasToggleTarget) {
      const el = this.contentTarget
      this._collapsedMaxHeight = el.style.maxHeight || ""
      if (el.scrollHeight <= el.clientHeight + 2) {
        this.toggleTarget.hidden = true
      }
    }
  }

  toggle() {
    const el = this.contentTarget
    const btn = this.toggleTarget
    const expanded = el.dataset.expanded === "true"

    if (expanded) {
      el.style.maxHeight = this._collapsedMaxHeight
      el.style.overflow = "hidden"
      el.dataset.expanded = "false"
      btn.textContent = "more"
    } else {
      el.style.maxHeight = "none"
      el.style.overflow = "visible"
      el.dataset.expanded = "true"
      btn.textContent = "less"
    }
  }
}
