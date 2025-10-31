import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["hero", "heroOutline", "heroContent", "overlay"];

  connect() {
    this.heroImage = this.heroTarget.children[0];

    this.heroImage.addEventListener("load", this.onLoad.bind(this));
    document.addEventListener("scroll", this.onScroll.bind(this));
    this.onScroll();
  }

  disconnect() {
    this.heroImage.removeEventListener("load", this.onLoad.bind(this));
    document.removeEventListener("scroll", this.onScroll.bind(this));
  }

  onLoad() {
    this.heroHeight = this.heroTarget.offsetHeight;
  }

  onScroll() {
    const scrollPercent = Math.max(
      0,
      Math.min(
        100,
        (window.scrollY / (this.heroHeight || window.innerHeight)) * 100
      )
    );

    let angle = 180 + ((120 - 180) * scrollPercent) / 100;
    let percent = 100 - (30 + (70 * scrollPercent) / 100);

    this.heroTarget.style.maskImage = `linear-gradient(${angle}deg, rgba(0,0,0,0.4) ${percent}%, rgba(0,0,0,0) ${percent}%)`;
    this.heroOutlineTarget.style.maskImage = `linear-gradient(${angle}deg, rgba(0,0,0,0) ${percent}%, rgba(0,0,0,1) ${percent}%)`;
    this.overlayTarget.style.maskImage = `linear-gradient(${angle}deg, rgba(0,0,0,1) ${percent}%, rgba(0,0,0,0) ${percent}%)`;
  }
}
