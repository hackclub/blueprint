import { Controller } from "@hotwired/stimulus"

// Prefills the second-pass build review form from a first-pass proposal's values
// so an admin can tweak them before submitting (the "Edit" quick-action).
export default class extends Controller {
  edit(event) {
    const data = event.currentTarget.dataset
    const form = this.element.querySelector("form[data-controller~='build-review-calculator']")
    if (!form) return

    const setField = (name, value) => {
      const field = form.querySelector(`[name="build_review[${name}]"]`)
      if (!field) return
      field.value = value ?? ""
      // Notify the ticket calculator + autofill controllers so previews update.
      field.dispatchEvent(new Event("input", { bubbles: true }))
      field.dispatchEvent(new Event("change", { bubbles: true }))
    }

    setField("hours_override", data.hoursOverride)
    setField("tier_override", data.tierOverride)
    setField("ticket_multiplier", data.ticketMultiplier)
    setField("ticket_offset", data.ticketOffset)
    setField("reason", data.reason)
    setField("feedback", data.feedback)

    form.scrollIntoView({ behavior: "smooth", block: "start" })
  }
}
