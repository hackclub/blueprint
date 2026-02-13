import { Controller } from "@hotwired/stimulus"

// Example wiring:
//   <div data-controller="tabs" data-tabs-active-tab-value="profile">
//     <button data-tabs-target="tab" data-tabs-name="profile"
//             data-tabs-active-class="border-b-4 border-white"
//             data-tabs-inactive-class="text-white/60"
//             data-action="click->tabs#select">Profile</button>
//     <button data-tabs-target="tab" data-tabs-name="billing"
//             data-tabs-active-class="border-b-4 border-white"
//             data-tabs-inactive-class="text-white/60"
//             data-action="click->tabs#select">Billing</button>
//     <section data-tabs-target="panel" data-tabs-name="profile">...</section>
//     <section data-tabs-target="panel" data-tabs-name="billing">...</section>
//     <button data-action="click->tabs#showNone">Hide all</button>
//   </div>
export default class extends Controller {
  static targets = ["tab", "panel"]

  static values = {
    activeTab: String,
    hiddenClass: { type: String, default: "hidden" }
  }

  connect() {
    this._applyActiveTab(this.hasActiveTabValue ? this.activeTabValue : null)
  }

  select(event) {
    const name = event?.params?.name || this._nameFor(event.currentTarget)
    if (!name) return
    this.show(name)
  }

  show(name) {
    if (!name) return this.showNone()
    this.activeTabValue = name
    this._applyActiveTab(name)
  }

  showNone() {
    if (this.hasActiveTabValue) this.activeTabValue = ""
    this._applyActiveTab(null)
  }

  _applyActiveTab(nameOrNull) {
    this.panelTargets.forEach((panel) => {
      const panelName = this._nameFor(panel)
      const active = !!nameOrNull && panelName === nameOrNull

      panel.hidden = !active
      panel.setAttribute("aria-hidden", String(!active))

      this._toggleClasses(panel, panel.dataset.tabsActiveClass, active)
      this._toggleClasses(panel, panel.dataset.tabsInactiveClass, !active)
      this._toggleClasses(panel, this.hiddenClassValue, !active)
    })

    this.tabTargets.forEach((tab) => {
      const tabName = this._nameFor(tab)
      const active = !!nameOrNull && tabName === nameOrNull

      tab.setAttribute("aria-selected", String(active))
      tab.setAttribute("tabindex", active ? "0" : "-1")

      this._toggleClasses(tab, tab.dataset.tabsActiveClass, active)
      this._toggleClasses(tab, tab.dataset.tabsInactiveClass, !active)
    })
  }

  _nameFor(el) {
    return el?.dataset?.tabsName
  }

  _toggleClasses(el, classNames, on) {
    if (!classNames) return
    classNames.split(/\s+/).forEach((className) => {
      if (className) el.classList.toggle(className, !!on)
    })
  }
}
