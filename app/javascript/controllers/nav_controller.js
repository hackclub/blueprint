import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["link", "submenu", "sublink", "panel", "backdrop"]

  connect() {
    this.update = this.update.bind(this)
    document.addEventListener("turbo:load", this.update)
    document.addEventListener("turbo:render", this.update)
    this.update()

    // Ensure closed on small screens by default and clean up any scroll locks
    if (this.hasPanelTarget) {
      this.panelTarget.classList.add("-translate-x-full")
      this.panelTarget.setAttribute("aria-hidden", "true")
    }
    if (this.hasBackdropTarget) {
      this.backdropTarget.classList.add("hidden")
    }
    // Always ensure scroll is unlocked on initial load
    const root = document.documentElement
    root.classList.remove("overflow-hidden", "md:overflow-auto")

    // Close on Turbo navigation to avoid stale open state
    this._onTurboLoad = () => {
      this.close(true)
    }
    document.addEventListener("turbo:load", this._onTurboLoad)

    // Close on ESC
    this._onKeydown = (e) => {
      if (e.key === "Escape") this.close()
    }
    document.addEventListener("keydown", this._onKeydown)
  }

  disconnect() {
    document.removeEventListener("turbo:load", this.update)
    document.removeEventListener("turbo:render", this.update)
    document.removeEventListener("turbo:load", this._onTurboLoad)
    document.removeEventListener("keydown", this._onKeydown)
  }

  open() {
    if (!this.hasPanelTarget) return
    this.panelTarget.classList.remove("-translate-x-full")
    this.panelTarget.setAttribute("aria-hidden", "false")
    if (this.hasBackdropTarget) this.backdropTarget.classList.remove("hidden")
    this._setHamburgerAria(true)
    this._lockScroll(true)
  }

  close(silent = false) {
    if (!this.hasPanelTarget) return
    this.panelTarget.classList.add("-translate-x-full")
    this.panelTarget.setAttribute("aria-hidden", "true")
    if (this.hasBackdropTarget) this.backdropTarget.classList.add("hidden")
    this._setHamburgerAria(false)
    if (!silent) this._lockScroll(false)
  }

  toggle() {
    if (!this.hasPanelTarget) return
    const isOpen = !this.panelTarget.classList.contains("-translate-x-full")
    isOpen ? this.close() : this.open()
  }

  _setHamburgerAria(expanded) {
    const btn = document.querySelector('[aria-controls="global-nav"]')
    if (btn) btn.setAttribute("aria-expanded", expanded ? "true" : "false")
  }

  _lockScroll(lock) {
    const root = document.documentElement
    if (lock) {
      root.classList.add("overflow-hidden", "md:overflow-auto")
    } else {
      root.classList.remove("overflow-hidden", "md:overflow-auto")
    }
  }

  update() {
    const currentPath = window.location.pathname

    // Toggle top-level nav active state (supports anchors or containers with data-nav-base or a child <a>)
    this.linkTargets.forEach((link) => {
      const match = link.dataset.navMatch || "exact"
      const explicitBase = (link.dataset.navBase || link.dataset.linkBase || link.dataset.navPath || "").replace(/\/$/, "")

      // Determine a pathname to compare against
      let pathname = ""
      if (explicitBase) {
        pathname = explicitBase
      } else if (link.pathname) {
        pathname = link.pathname.replace(/\/$/, "")
      } else {
        const a = link.querySelector && link.querySelector('a[href]')
        if (a) {
          try {
            pathname = new URL(a.getAttribute('href'), window.location.origin).pathname.replace(/\/$/, "")
          } catch (_) {}
        }
      }

      let isActive = false
      if (match === "prefix") {
        const base = pathname
        isActive = base && (currentPath === base || currentPath.startsWith(base + "/"))
      } else {
        isActive = pathname && pathname === currentPath
      }

      this.toggleVariant(link, isActive)
      if (isActive) link.setAttribute("aria-current", "page")
      else link.removeAttribute("aria-current")
    })

    // Toggle submenus based on base path
    this.submenuTargets.forEach((submenu) => {
      const base = (submenu.dataset.submenuBase || "").replace(/\/$/, "")
      const expanded = base && (currentPath === base || currentPath.startsWith(base + "/"))
      submenu.classList.toggle("hidden", !expanded)
    })

    // Update sublinks highlighting (underline active)
    if (this.hasSublinkTarget) {
      this.sublinkTargets.forEach((link) => {
        const match = link.dataset.navMatch || "exact"
        let isActive = false
        if (match === "prefix") {
          const base = link.pathname.replace(/\/$/, "")
          isActive = currentPath === base || currentPath.startsWith(base + "/")
        } else {
          isActive = link.pathname === currentPath
        }
        link.classList.toggle("underline", isActive)
        if (isActive) link.setAttribute("aria-current", "page")
        else link.removeAttribute("aria-current")
      })
    }
  }

  toggleVariant(el, active) {
    const ACTIVE = "btn-nav-active"
    const INACTIVE = "btn-nav"
    const isDisabled = el.classList.contains("pointer-events-none")
    if (active && !isDisabled) {
      el.classList.add(ACTIVE)
      el.classList.remove(INACTIVE)
    } else {
      el.classList.add(INACTIVE)
      el.classList.remove(ACTIVE)
    }
  }
}
