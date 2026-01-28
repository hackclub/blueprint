import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["hero", "heroOutline", "heroContent", "overlay"];

  connect() {
    this.heroImage = this.heroTarget.children[0];
    this.ticking = false;
    this.boundOnLoad = this.onLoad.bind(this);
    this.boundOnScroll = this.onScroll.bind(this);

    this.heroImage.addEventListener("load", this.boundOnLoad);
    document.addEventListener("scroll", this.boundOnScroll, { passive: true });

    if (this.heroImage.complete) {
      this.heroHeight = this.heroTarget.offsetHeight;
    }
    this.scheduleUpdate();
  }

  disconnect() {
    this.heroImage.removeEventListener("load", this.boundOnLoad);
    document.removeEventListener("scroll", this.boundOnScroll);
  }

  onLoad() {
    this.heroHeight = this.heroTarget.offsetHeight;
  }

  onScroll() {
    this.scheduleUpdate();
  }

  scheduleUpdate() {
    if (this.ticking) return;

    this.ticking = true;
    requestAnimationFrame(() => {
      this.updateMasks();
      this.ticking = false;
    });
  }

  updateMasks() {
    const scrollPercent = Math.max(
      0,
      Math.min(
        100,
        (window.scrollY / (this.heroHeight || window.innerHeight)) * 100
      )
    );

    const angle = 180 + ((120 - 180) * scrollPercent) / 100;
    const percent = 100 - (30 + (70 * scrollPercent) / 100);
    const mask = `linear-gradient(${angle}deg, rgba(0,0,0,0.4) ${percent}%, rgba(0,0,0,0) ${percent}%)`;
    const outlineMask = `linear-gradient(${angle}deg, rgba(0,0,0,0) ${percent}%, rgba(0,0,0,1) ${percent}%)`;
    const overlayMask = `linear-gradient(${angle}deg, rgba(0,0,0,1) ${percent}%, rgba(0,0,0,0) ${percent}%)`;

    this.heroTarget.style.maskImage = mask;
    this.heroOutlineTarget.style.maskImage = outlineMask;
    this.overlayTarget.style.maskImage = overlayMask;
  }
}
