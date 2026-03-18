import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select"]

  connect() {
    this.selectTarget.style.display = "none"
    this.buildUI()
    this.preselectValue()
  }

  buildUI() {
    const wrapper = document.createElement("div")
    wrapper.className = "relative"

    this.input = document.createElement("input")
    this.input.type = "text"
    this.input.placeholder = "Search for a country..."
    this.input.className = this.selectTarget.className
    this.input.addEventListener("input", () => this.onInput())
    this.input.addEventListener("focus", () => this.open())
    this.input.addEventListener("keydown", (e) => this.onKeydown(e))

    this.dropdown = document.createElement("ul")
    this.dropdown.className =
      "absolute z-50 left-0 right-0 max-h-60 overflow-y-auto bg-bp-dark border border-white/25 text-white hidden"
    this.dropdown.style.top = "100%"

    wrapper.appendChild(this.input)
    wrapper.appendChild(this.dropdown)
    this.element.insertBefore(wrapper, this.selectTarget)

    this.buildOptions()

    document.addEventListener("click", (e) => {
      if (!wrapper.contains(e.target)) this.close()
    })
  }

  buildOptions() {
    this.dropdown.innerHTML = ""
    this.highlightedIndex = -1

    Array.from(this.selectTarget.options).forEach((option) => {
      if (!option.value) return // skip blank placeholder

      const li = document.createElement("li")
      li.textContent = option.text
      li.dataset.value = option.value
      li.className = "px-3 py-2 cursor-pointer hover:bg-bp-lighter"
      li.addEventListener("mousedown", (e) => {
        e.preventDefault()
        this.pick(option.value, option.text)
      })
      this.dropdown.appendChild(li)
    })
  }

  preselectValue() {
    const selected = this.selectTarget.options[this.selectTarget.selectedIndex]
    if (selected && selected.value) {
      this.input.value = selected.text
    }
  }

  onInput() {
    const filter = this.input.value.toLowerCase()
    const items = this.dropdown.querySelectorAll("li")
    items.forEach((li) => {
      li.style.display = li.textContent.toLowerCase().includes(filter)
        ? ""
        : "none"
    })
    this.highlightedIndex = -1
    this.open()
  }

  onKeydown(e) {
    const visible = Array.from(this.dropdown.querySelectorAll("li")).filter(
      (li) => li.style.display !== "none"
    )
    if (!visible.length) return

    if (e.key === "ArrowDown") {
      e.preventDefault()
      this.highlightedIndex = Math.min(
        this.highlightedIndex + 1,
        visible.length - 1
      )
      this.updateHighlight(visible)
    } else if (e.key === "ArrowUp") {
      e.preventDefault()
      this.highlightedIndex = Math.max(this.highlightedIndex - 1, 0)
      this.updateHighlight(visible)
    } else if (e.key === "Enter") {
      e.preventDefault()
      if (this.highlightedIndex >= 0 && visible[this.highlightedIndex]) {
        const li = visible[this.highlightedIndex]
        this.pick(li.dataset.value, li.textContent)
      }
    } else if (e.key === "Escape") {
      this.close()
    }
  }

  updateHighlight(visible) {
    visible.forEach((li, i) => {
      li.classList.toggle("bg-bp-lighter", i === this.highlightedIndex)
    })
    if (visible[this.highlightedIndex]) {
      visible[this.highlightedIndex].scrollIntoView({ block: "nearest" })
    }
  }

  pick(value, text) {
    this.selectTarget.value = value
    this.input.value = text
    this.close()
  }

  open() {
    this.dropdown.classList.remove("hidden")
  }

  close() {
    this.dropdown.classList.add("hidden")
    this.highlightedIndex = -1
  }
}
