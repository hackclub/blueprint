import { Controller } from "@hotwired/stimulus"
import { csrfHeader } from "helpers/csrf"

// data-controller="project-validator"
// Targets: title, description, repo, status (message under repo), submit (button)
export default class extends Controller {
  static targets = ["title", "description", "repo", "status", "submit"]
  static values = {
    debounce: { type: Number, default: 700 },
    url: { type: String, default: "/projects/check_github_repo" },
    projectId: { type: Number, default: null },
  }

  connect() {
    this._timer = null
    this._abort = null
    this._repoState = { kind: "idle" } // idle | empty | checking | ok | no_push | error

    // Initial validation on connect
    this.validate()

    // If repo has a value on load, kick off a check
    if (this.hasRepoTarget) {
      const value = (this.repoTarget.value || "").trim()
      if (value.length > 0) this.queueRepoCheck()
    }
  }

  disconnect() {
    if (this._timer) clearTimeout(this._timer)
    if (this._abort) this._abort.abort()
  }

  // Event handlers
  validate() {
    const title = this.hasTitleTarget ? (this.titleTarget.value || "").trim() : ""
    const desc = this.hasDescriptionTarget ? (this.descriptionTarget.value || "").trim() : ""
    const repo = this.hasRepoTarget ? (this.repoTarget.value || "").trim() : ""

    // Determine repo validity
    let repoValid = true
    if (repo.length === 0) {
      this._repoState = { kind: "empty" }
      repoValid = true
      // Don't force any status if empty; clear it
      this.clearStatus()
    } else {
      // If we don't have a positive result, it's not valid yet
      if (this._repoState.kind === "ok") {
        repoValid = true
      } else if (this._repoState.kind === "no_push" || this._repoState.kind === "error") {
        repoValid = false
      } else {
        // idle or checking -> not valid yet
        repoValid = false
      }
    }

    const formValid = title.length > 0 && desc.length > 0 && repoValid

    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = !formValid
    }
  }

  queueRepoCheck() {
    if (!this.hasRepoTarget) return

    const value = (this.repoTarget.value || "").trim()

    if (value.length === 0) {
      this._repoState = { kind: "empty" }
      this.setStatus("", { neutral: true })
      this.validate()
      if (this._timer) clearTimeout(this._timer)
      return
    }

    if (!this.isGitHubRepo(value)) {
      this._repoState = { kind: "ok" }
      this.setStatus("Non-GitHub repository detected. Verification skipped.", { neutral: true })
      this.validate()
      if (this._timer) clearTimeout(this._timer)
      return
    }

    this._repoState = { kind: "checking" }
    this.setStatus("Checking…", { neutral: true })
    this.validate()

    if (this._timer) clearTimeout(this._timer)
    this._timer = setTimeout(() => this.runRepoCheck(value), this.debounceValue)
  }

  isGitHubRepo(repo) {
    const trimmed = repo.trim()
    
    if (trimmed.match(/^https?:\/\/github\.com\//i)) return true
    if (trimmed.match(/^git@github\.com:/i)) return true
    if (trimmed.match(/^github\.com\//i)) return true
    if (trimmed.match(/^[^\/]+\/[^\/]+$/)) return true
    if (trimmed.match(/^[\w.-]+$/)) return true
    
    return false
  }

  async runRepoCheck(repo) {
    // Cancel any in-flight request
    if (this._abort) this._abort.abort()
    this._abort = new AbortController()

    try {
      const res = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          ...csrfHeader(),
        },
        body: JSON.stringify({ repo, project_id: this.projectIdValue }),
        signal: this._abort.signal,
      })

      if (!res.ok) {
        this._repoState = { kind: "error" }
        let message = "Error checking repository."
        try {
          const data = await res.json()
          message = data.error || message
        } catch {}
        this.setStatus(message, { danger: true })
        this.validate()
        return
      }

      const data = await res.json()
      if (data.ok) {
        if (data.can_push) {
          this._repoState = { kind: "ok" }
          this.setStatus("You can write to this repository.", { success: true })
        } else {
          this._repoState = { kind: "no_push" }
          this.setStatus("You do not have write access to this repository.", { danger: true })
        }
      } else {
        const msg = data.error || "Unable to verify repository."
        this._repoState = { kind: "error" }
        this.setStatus(msg, { danger: true })
      }
      this.validate()
    } catch (e) {
      if (e?.name === "AbortError") return
      this._repoState = { kind: "error" }
      this.setStatus("Network error while checking repository.", { danger: true })
      this.validate()
    }
  }

  // Status helpers
  setStatus(text, { success = false, danger = false, neutral = false } = {}) {
    if (!this.hasStatusTarget) return
    const el = this.statusTarget

    el.textContent = text || ""
    el.classList.remove("text-bp-success", "text-bp-danger")

    if (success) {
      el.classList.add("text-bp-success")
    } else if (danger) {
      el.classList.add("text-bp-danger")
    }
  }

  clearStatus() {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = "You must have write access to the repository."
    this.statusTarget.classList.remove("text-bp-success", "text-bp-danger")
  }
}
