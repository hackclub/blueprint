import { Controller } from "@hotwired/stimulus"

// Keyboard shortcuts for the streamlined design review UI.
//
// Single-key (only when not focused in a text field):
//   r → open repo in new tab        s → open slack thread
//   o → toggle journal              w → toggle previous reviews
//   c → toggle cart screenshots     Esc → blur / cancel confirm
//
// Cmd/Ctrl (active even in text fields):
//   ⌘P → approve (confirm required)     ⌘E → return (immediate)
//   ⌘K → reject  (confirm required)     ⌘S → skip
//   ⌘J → focus justification            ⌘F → focus feedback

export default class extends Controller {
  static targets = [
    "approveBtn", "returnBtn", "rejectBtn", "skipBtn",
    "approveLabelSpan", "rejectLabelSpan",
    "justification", "feedback",
    "journalDetails", "reviewsDetails", "screenshotsDetails"
  ]
  static values = { repoUrl: String, slackUrl: String }

  connect() {
    this._onKeydown = this.handleKeydown.bind(this)
    this._onDocClick = this.handleDocClick.bind(this)
    document.addEventListener("keydown", this._onKeydown)
    document.addEventListener("click", this._onDocClick)
    this.pendingConfirm = null
  }

  disconnect() {
    document.removeEventListener("keydown", this._onKeydown)
    document.removeEventListener("click", this._onDocClick)
  }

  isInTextField() {
    const el = document.activeElement
    return el && (el.tagName === "INPUT" || el.tagName === "TEXTAREA" || el.isContentEditable)
  }

  handleDocClick(e) {
    if (!this.pendingConfirm) return
    const confirmBtns = [
      this.hasApproveBtnTarget ? this.approveBtnTarget : null,
      this.hasRejectBtnTarget  ? this.rejectBtnTarget  : null,
    ].filter(Boolean)
    if (!confirmBtns.some(btn => btn.contains(e.target))) this.clearConfirm()
  }

  handleKeydown(e) {
    const inText = this.isInTextField()

    if (e.key === "Escape") {
      if (inText) { document.activeElement.blur(); e.preventDefault() }
      else this.clearConfirm()
      return
    }

    // Cmd/Ctrl combos — active even in text fields
    if (e.metaKey || e.ctrlKey) {
      switch (e.key.toLowerCase()) {
        case "p": e.preventDefault(); this.triggerAction("approve"); return
        case "e": e.preventDefault(); this.triggerAction("return");  return
        case "k": e.preventDefault(); this.triggerAction("reject");  return
        case "s": e.preventDefault(); this.triggerAction("skip");    return
        case "j": if (this.hasJustificationTarget) { e.preventDefault(); this.focusAtEnd(this.justificationTarget) } return
        case "f": if (this.hasFeedbackTarget)       { e.preventDefault(); this.focusAtEnd(this.feedbackTarget) }      return
      }
      return
    }

    if (inText || e.altKey) return

    switch (e.key.toLowerCase()) {
      case "r": if (this.repoUrlValue)  { window.open(this.repoUrlValue,  "_blank"); e.preventDefault() } break
      case "s": if (this.slackUrlValue) { window.open(this.slackUrlValue, "_blank"); e.preventDefault() } break
      case "o": if (this.hasJournalDetailsTarget)     this.journalDetailsTarget.open     = !this.journalDetailsTarget.open;     break
      case "w": if (this.hasReviewsDetailsTarget)     this.reviewsDetailsTarget.open     = !this.reviewsDetailsTarget.open;     break
      case "c": if (this.hasScreenshotsDetailsTarget) this.screenshotsDetailsTarget.open = !this.screenshotsDetailsTarget.open; break
    }
  }

  toggleTheme() {
    const current = this.element.dataset.srTheme || "dark"
    const next = current === "dark" ? "light" : "dark"
    this.element.dataset.srTheme = next
    document.cookie = `sr_theme=${next}; path=/; max-age=${60 * 60 * 24 * 365}; SameSite=Lax`
  }

  focusAtEnd(el) {
    el.focus()
    const len = el.value.length
    el.setSelectionRange(len, len)
  }

  // Attached via data-action="click->review-keys#buttonClicked" on approve/reject
  buttonClicked(e) {
    e.preventDefault()
    this.triggerAction(e.currentTarget.dataset.reviewKeysAction)
  }

  triggerAction(action) {
    if (action === "skip")   { if (this.hasSkipBtnTarget) this.skipBtnTarget.click(); return }
    if (action === "return") { this.executeAction("return"); return }

    // Approve and reject need a second invocation to confirm
    if (this.pendingConfirm === action) {
      this.executeAction(action)
    } else {
      this.setPendingConfirm(action)
    }
  }

  setPendingConfirm(action) {
    if (this.pendingConfirm && this.pendingConfirm !== action) this.resetButtonLabel(this.pendingConfirm)
    this.pendingConfirm = action
    this.getLabelSpan(action).textContent = "Confirm?"
  }

  clearConfirm() {
    if (!this.pendingConfirm) return
    this.resetButtonLabel(this.pendingConfirm)
    this.pendingConfirm = null
  }

  resetButtonLabel(action) {
    const span = this.getLabelSpan(action)
    if (span) span.textContent = action === "approve" ? "Approve" : "Perm Reject"
  }

  executeAction(action) {
    this.pendingConfirm = null
    const btn = this.getBtnTarget(action)
    if (btn && btn.form) btn.form.requestSubmit(btn)
  }

  getLabelSpan(action) {
    if (action === "approve") return this.hasApproveLabelSpanTarget ? this.approveLabelSpanTarget : null
    if (action === "reject")  return this.hasRejectLabelSpanTarget  ? this.rejectLabelSpanTarget  : null
    return null
  }

  getBtnTarget(action) {
    if (action === "approve") return this.hasApproveBtnTarget ? this.approveBtnTarget : null
    if (action === "return")  return this.hasReturnBtnTarget  ? this.returnBtnTarget  : null
    if (action === "reject")  return this.hasRejectBtnTarget  ? this.rejectBtnTarget  : null
    return null
  }
}
