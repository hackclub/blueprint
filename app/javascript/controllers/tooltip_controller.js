import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = {
    text: String,
  };

  connect() {
    this._visible = false;
    this._raf = null;
    this._id =
      crypto?.randomUUID?.() || `tt-${Math.random().toString(36).slice(2)}`;
    this._onEnter = this._onEnter.bind(this);
    this._onLeave = this._onLeave.bind(this);
    this._onFocus = this._onFocus.bind(this);
    this._onBlur = this._onBlur.bind(this);
    this._onReposition = this._onReposition.bind(this);

    this.element.addEventListener("mouseenter", this._onEnter);
    this.element.addEventListener("mouseleave", this._onLeave);
    this.element.addEventListener("focus", this._onFocus, true);
    this.element.addEventListener("blur", this._onBlur, true);
  }

  disconnect() {
    this.hide();
    this.element.removeEventListener("mouseenter", this._onEnter);
    this.element.removeEventListener("mouseleave", this._onLeave);
    this.element.removeEventListener("focus", this._onFocus, true);
    this.element.removeEventListener("blur", this._onBlur, true);
    if (this._tooltip) this._tooltip.remove();
    this._tooltip = null;
  }

  show() {
    if (!this.hasTextValue || !this.textValue) return;
    if (!this._tooltip) this._buildTooltip();

    this._tooltip.hidden = false;
    this._tooltip.style.opacity = "0";
    this._tooltip.setAttribute("aria-hidden", "false");
    this.element.setAttribute("aria-describedby", this._id);
    this._visible = true;

    this._reposition();
    requestAnimationFrame(() => {
      if (this._tooltip) this._tooltip.style.opacity = "1";
    });

    window.addEventListener("scroll", this._onReposition, true);
    window.addEventListener("resize", this._onReposition);
  }

  hide() {
    if (!this._visible) return;
    this._visible = false;
    if (this._tooltip) {
      this._tooltip.style.opacity = "0";
      setTimeout(() => {
        if (!this._visible && this._tooltip) {
          this._tooltip.hidden = true;
          this._tooltip.setAttribute("aria-hidden", "true");
        }
      }, 90);
    }
    this.element.removeAttribute("aria-describedby");
    window.removeEventListener("scroll", this._onReposition, true);
    window.removeEventListener("resize", this._onReposition);
  }

  textValueChanged() {
    if (this._tooltip) {
      this._tooltipText.textContent = this.textValue || "";
      if (this._visible) this._reposition();
    }
  }

  _onEnter() {
    this.show();
  }

  _onLeave() {
    this.hide();
  }

  _onFocus() {
    this.show();
  }

  _onBlur() {
    this.hide();
  }

  _onReposition() {
    this._reposition();
  }

  _buildTooltip() {
    const el = document.createElement("div");
    el.id = this._id;
    el.setAttribute("role", "tooltip");
    el.setAttribute("aria-hidden", "true");
    el.hidden = true;
    el.style.opacity = "0";
    el.style.transition = "opacity 40ms ease-out";
    el.className = [
      "fixed z-50 pointer-events-none",
      "rounded-md bg-gray-900 text-white text-sm font-medium",
      "px-2 py-1 shadow-lg ring-1 ring-black/10",
      "whitespace-nowrap max-w-xs",
    ].join(" ");

    const textNode = document.createElement("span");
    textNode.textContent = this.textValue || "";
    el.appendChild(textNode);

    this._tooltip = el;
    this._tooltipText = textNode;
    document.body.appendChild(el);
  }

  _reposition() {
    if (!this._visible || !this._tooltip) return;
    if (this._raf) cancelAnimationFrame(this._raf);
    this._raf = requestAnimationFrame(() => {
      const targetRect = this.element.getBoundingClientRect();
      if (targetRect.width === 0 && targetRect.height === 0) return;

      this._tooltip.style.left = "0px";
      this._tooltip.style.top = "0px";

      const spacing = -4;
      const margin = 8;
      const vw = window.innerWidth;
      const vh = window.innerHeight;
      const ttRect = this._tooltip.getBoundingClientRect();

      const canTop = targetRect.top >= ttRect.height + spacing;
      const placeTop = canTop;
      const top = placeTop
        ? Math.round(targetRect.top - ttRect.height - spacing)
        : Math.round(targetRect.bottom + spacing);

      let left = Math.round(
        targetRect.left + targetRect.width / 2 - ttRect.width / 2
      );
      left = Math.min(Math.max(left, margin), vw - ttRect.width - margin);

      if (
        !placeTop &&
        top + ttRect.height + margin > vh &&
        targetRect.top >= ttRect.height + spacing
      ) {
        const correctedTop = Math.round(
          targetRect.top - ttRect.height - spacing
        );
        this._tooltip.style.top = `${correctedTop}px`;
      } else {
        this._tooltip.style.top = `${top}px`;
      }
      this._tooltip.style.left = `${left}px`;
    });
  }
}
