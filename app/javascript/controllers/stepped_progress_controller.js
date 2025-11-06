import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["step", "progress"];
  static values = {
    currentStep: { type: Number, default: 1 },
    completeClasses: { type: String, default: "bg-bp-success text-bp-dark" },
    currentClasses: {
      type: String,
      default: "border-4 border-bp-success text-bp-success bg-bp-dark",
    },
    incompleteClasses: {
      type: String,
      default: "border-4 border-white text-white bg-bp-dark",
    },
  };

  currentStepValueChanged(newVal, oldVal) {
    this.update();
  }

  next() {
    this.currentStepValue++;
  }

  prev() {
    this.currentStepValue--;
  }

  update() {
    this.numTargets = this.stepTargets.length;
    this.updateTargets();
    this.updateProgressBar();
  }

  updateTargets() {
    let currentTargets = this.stepTargets[this.currentStepValue - 1];
    let completeTargets = this.stepTargets.slice(0, this.currentStepValue - 1);
    let incompleteTargets = this.stepTargets.slice(this.currentStepValue);

    // for current target, remove this.completeClassesValue and this.incompleteClassesValue and add this.currentClassesValue to the classlist
    currentTargets.classList.remove(
      ...this.completeClassesValue.split(" "),
      ...this.incompleteClassesValue.split(" ")
    );
    currentTargets.classList.add(...this.currentClassesValue.split(" "));

    // for complete targets
    completeTargets.forEach((target) => {
      target.classList.remove(
        ...this.currentClassesValue.split(" "),
        ...this.incompleteClassesValue.split(" ")
      );
      target.classList.add(...this.completeClassesValue.split(" "));
    });

    // for incomplete targets
    incompleteTargets.forEach((target) => {
      target.classList.remove(
        ...this.completeClassesValue.split(" "),
        ...this.currentClassesValue.split(" ")
      );
      target.classList.add(...this.incompleteClassesValue.split(" "));
    });
  }

  updateProgressBar() {
    let percentage =
      ((this.currentStepValue - 1) / (this.numTargets - 1)) * 100;
    // set the width of progressTarget to this percent
    this.progressTarget.style.width = `${percentage}%`;
  }
}
