import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["quantityInput", "quantityDisplay", "totalCost", "insufficientFunds", "submitButton"]
  static values = {
    unitPrice: Number,
    userBalance: Number
  }

  connect() {
    this.updateTotal()
  }

  updateTotal() {
    const quantity = parseInt(this.quantityInputTarget.value) || 1
    const total = this.unitPriceValue * quantity

    this.quantityDisplayTarget.textContent = quantity
    this.totalCostTarget.textContent = `${total} tickets`

    if (total > this.userBalanceValue) {
      const shortfall = total - this.userBalanceValue
      this.insufficientFundsTarget.textContent = `Insufficient funds! You need ${shortfall} more tickets.`
      this.insufficientFundsTarget.classList.remove('hidden')
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.classList.add('opacity-50', 'cursor-not-allowed')
    } else {
      this.insufficientFundsTarget.classList.add('hidden')
      this.submitButtonTarget.disabled = false
      this.submitButtonTarget.classList.remove('opacity-50', 'cursor-not-allowed')
    }
  }
}
