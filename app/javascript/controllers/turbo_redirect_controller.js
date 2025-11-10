import { Controller } from "@hotwired/stimulus";
import { Turbo } from "@hotwired/turbo-rails";

export default class extends Controller {
  connect() {
    Turbo.StreamActions.redirect = function () {
      const url = this.getAttribute("url") || this.target;
      Turbo.visit(url);
    };
  }
}
