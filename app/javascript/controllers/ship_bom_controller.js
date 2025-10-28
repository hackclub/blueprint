import { Controller } from "@hotwired/stimulus"
import { csrfHeader } from "helpers/csrf"

// data-controller="ship-bom"
// data-ship-bom-project-id-value
// Targets: box, submit, select
export default class extends Controller {
  static targets = ["box", "submit", "select"]
  static values = {
    projectId: Number,
    url: { type: String, default: "/projects/check_bom" },
    readmeUrl: { type: String, default: "/projects/check_readme" },
    baseOk: { type: Boolean, default: false },
  }

  connect() {
    this._bomState = "pending"
    this._readmeState = "pending"
    this.ensureSelectValue()
    this.updateDisabled()
    this.check()

    if (this.hasSelectTarget) {
      this._onSelectChange = () => this.updateDisabled()
      this.selectTarget.addEventListener("change", this._onSelectChange)
    }
  }

  disconnect() {
    if (this.hasSelectTarget && this._onSelectChange) {
      this.selectTarget.removeEventListener("change", this._onSelectChange)
    }
  }

  ensureSelectValue() {
    if (!this.hasSelectTarget) return
    const sel = this.selectTarget
    const val = (sel.value || "").toString().trim()
    if (val !== "") return

    const firstValid = Array.from(sel.options).find((opt) => (opt.value || "").toString().trim() !== "")
    if (firstValid) {
      sel.value = firstValid.value
      sel.dispatchEvent(new Event("change", { bubbles: true }))
    }
  }

  async check() {
    const checks = []
    if (this.boxTargets.some((e) => e.dataset.check === "bom")) {
      checks.push(this.checkOne(this.urlValue, "bom"))
    }
    if (this.boxTargets.some((e) => e.dataset.check === "readme")) {
      checks.push(this.checkOne(this.readmeUrlValue, "readme"))
    }
    await Promise.all(checks)
  }

  async checkOne(url, type) {
    const body = JSON.stringify({ project_id: this.projectIdValue })
    try {
      const res = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          ...csrfHeader(),
        },
        body,
      })

      if (!res.ok) {
        this.setDanger(type)
        return
      }

      const data = await res.json()
      if (data.ok && data.exists === true) {
        this.setSuccess(type)
      } else if (data.ok && data.exists === false) {
        this.setDanger(type)
      } else {
        this.setDanger(type)
      }
    } catch (_e) {
      this.setDanger(type)
    }
  }

  boxFor(type) {
    const el = this.boxTargets.find((e) => e.dataset.check === type)
    return el || this.boxTargets[0]
  }

  setSuccess(type = "bom") {
    const el = this.boxFor(type)
    if (el) {
      el.classList.remove(
        "border-bp-muted",
        "bg-bp-danger",
        "border-bp-danger",
        "border-bp-warning",
        "border-dashed",
        "animate-spin",
        "rounded-full"
      )
      el.classList.add("bg-bp-success", "border-bp-success")
    }
    if (type === "bom") {
      this._bomState = "ok"
    } else if (type === "readme") {
      this._readmeState = "ok"
    }
    this.updateDisabled()
  }

  setDanger(type = "bom") {
    const el = this.boxFor(type)
    if (el) {
      el.classList.remove(
        "border-bp-muted",
        "bg-bp-success",
        "border-bp-success",
        "border-bp-warning",
        "border-dashed",
        "animate-spin",
        "rounded-full"
      )
      el.classList.add("bg-bp-danger", "border-bp-danger")
    }
    if (type === "bom") {
      this._bomState = "fail"
    } else if (type === "readme") {
      this._readmeState = "fail"
    }
    this.updateDisabled()
  }

  updateDisabled() {
    if (!this.hasSubmitTarget) return
    const hasBom = this.boxTargets.some((e) => e.dataset.check === "bom")
    const bomOk = hasBom ? this._bomState === "ok" : true
    const hasReadme = this.boxTargets.some((e) => e.dataset.check === "readme")
    const readmeOk = hasReadme ? this._readmeState === "ok" : true
    const tierOk = this.hasSelectTarget ? ((this.selectTarget.value || "").toString().trim() !== "") : true
    const allOk = !!this.baseOkValue && bomOk && readmeOk && tierOk
    
    console.log("Ship validation:", { baseOk: this.baseOkValue, bomOk, readmeOk, tierOk, allOk })
    
    this.submitTarget.disabled = !allOk
  }

  handlePrev(event) {
    event.preventDefault()
    
    const needsFundingRadio = document.querySelector('input[name="project[needs_funding]"]:checked')
    const needsFunding = needsFundingRadio ? needsFundingRadio.value === "true" : true
    
    const paginateController = this.application.getControllerForElementAndIdentifier(
      document.querySelector('[data-controller*="paginate"]'),
      "paginate"
    )
    
    if (paginateController) {
      if (needsFunding) {
        paginateController.prev()
      } else {
        paginateController.prevJump()
      }
    }
  }
}
