import { Controller } from "@hotwired/stimulus"

// Redirects to HCA signup with the entered email as a URL param
export default class extends Controller {
  static targets = ["input"]
  static values = { 
    hcaSignupUrl: String,
    clientId: String,
    callbackUrl: String,
    scope: String
  }

  async go() {
    const email = (this.inputTarget?.value || "").trim()
    
    const state = await this.track(email)
    if (!state) {
      console.error("Failed to get state from track endpoint")
      return
    }

    const returnTo = this.buildReturnTo(state)
    const hcaUrl = new URL(this.hcaSignupUrlValue)
    if (email.length > 0) {
      hcaUrl.searchParams.set("email", email)
    }
    hcaUrl.searchParams.set("return_to", returnTo)
    window.location.assign(hcaUrl.toString())
  }

  buildReturnTo(state) {
    const params = new URLSearchParams({
      client_id: this.clientIdValue,
      redirect_uri: this.callbackUrlValue,
      response_type: "code",
      scope: this.scopeValue,
      state: state
    })
    return `/oauth/authorize?${params.toString()}`
  }
  
  checkEnter(event) {
    if (event.key === "Enter") {
      this.go()
    }
  }

  async track(email) {
    try {
      const response = await fetch("/auth/track", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ email }),
      })
      if (response.ok) {
        const data = await response.json()
        return data.state
      }
    } catch (e) {
      console.error(e)
    }
    return null
  }
}
