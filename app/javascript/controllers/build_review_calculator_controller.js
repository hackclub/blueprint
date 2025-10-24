import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tier", "multiplier", "offset", "hoursOverride", "tickets", "hours", "displayMultiplier", "displayOffset"]
  static values = {
    projectTier: Number,
    hoursSinceLastReview: Number
  }

  connect() {
    this.tierMultipliers = {
      1: 1.5,
      2: 1.25,
      3: 1.1,
      4: 1.0,
      5: 0.8,
      null: 0.8
    }
    this.calculate()
  }

  getDefaultMultiplier(tier) {
    return this.tierMultipliers[tier] || 0.8
  }

  calculate() {
    const selectedTier = this.tierTarget.value ? parseInt(this.tierTarget.value) : this.projectTierValue
    const defaultMultiplier = this.getDefaultMultiplier(selectedTier)
    
    const multiplier = parseFloat(this.multiplierTarget.value) || defaultMultiplier
    const offset = parseInt(this.offsetTarget.value) || 0
    
    // Use hours override if present, otherwise use calculated hours
    const hours = parseFloat(this.hoursOverrideTarget.value) || this.hoursSinceLastReviewValue
    
    // Base rate is 10 tickets/hour, multiplier adjusts that rate
    const tickets = Math.round((hours * 10 * multiplier) + offset)
    
    this.ticketsTarget.textContent = tickets
    this.hoursTarget.textContent = hours.toFixed(2)
    this.displayMultiplierTarget.textContent = multiplier.toFixed(2)
    this.displayOffsetTarget.textContent = offset
    
    if (!this.multiplierTarget.value) {
      const tierLabel = selectedTier || 'None'
      this.multiplierTarget.placeholder = `Auto-calculated based on tier (×${defaultMultiplier.toFixed(1)}, Tier ${tierLabel})`
    }
  }

  tierChanged() {
    if (!this.multiplierTarget.value) {
      const selectedTier = this.tierTarget.value ? parseInt(this.tierTarget.value) : this.projectTierValue
      const defaultMultiplier = this.getDefaultMultiplier(selectedTier)
      const tierLabel = selectedTier || 'None'
      this.multiplierTarget.placeholder = `Auto-calculated based on tier (×${defaultMultiplier.toFixed(1)}, Tier ${tierLabel})`
    }
    this.calculate()
  }
}
