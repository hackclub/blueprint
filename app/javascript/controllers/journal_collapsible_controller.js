import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.makeEntriesCollapsible()
  }

  makeEntriesCollapsible() {
    const content = this.element.querySelector('.markdown')
    if (!content) return

    const children = Array.from(content.children)
    const entries = []
    let currentEntry = null

    children.forEach(child => {
      // Check if this H1 contains "Time spent:" in the next sibling (it's a timestamp header)
      if (child.tagName === 'H1' && 
          child.nextElementSibling && 
          child.nextElementSibling.tagName === 'P' && 
          child.nextElementSibling.textContent.includes('Time spent:')) {
        // Save previous entry
        if (currentEntry) {
          entries.push(currentEntry)
        }
        // Start new entry with the timestamp header
        currentEntry = {
          header: child,
          timeSpent: child.nextElementSibling.textContent.match(/Time spent: (.+)/)?.[1] || '',
          content: []
        }
      } else if (currentEntry) {
        // Add everything else to the current entry
        currentEntry.content.push(child)
      }
    })

    // Push the last entry
    if (currentEntry) {
      entries.push(currentEntry)
    }

    // Transform each entry into a collapsible details element
    entries.forEach(entry => {
      const details = document.createElement('details')
      details.open = true

      const summary = document.createElement('summary')
      summary.style.cursor = 'pointer'
      summary.style.listStyle = 'none'
      
      // Create header text with time when collapsed
      const headerText = document.createElement('span')
      headerText.innerHTML = entry.header.innerHTML
      
      const timeSpan = document.createElement('span')
      timeSpan.className = 'time-indicator'
      timeSpan.style.marginLeft = '0.5rem'
      timeSpan.style.fontWeight = 'normal'
      timeSpan.style.fontSize = '0.875rem'
      timeSpan.style.color = '#6B7280'
      timeSpan.textContent = entry.timeSpent ? `(${entry.timeSpent})` : ''
      
      summary.appendChild(headerText)
      summary.appendChild(timeSpan)

      // Hide time indicator when expanded
      details.addEventListener('toggle', () => {
        timeSpan.style.display = details.open ? 'none' : 'inline'
      })
      
      // Initially hide since details start open
      timeSpan.style.display = 'none'

      const contentWrapper = document.createElement('div')
      entry.content.forEach(node => {
        contentWrapper.appendChild(node)
      })

      details.appendChild(summary)
      details.appendChild(contentWrapper)

      // Replace the original header with the details element
      entry.header.parentNode.insertBefore(details, entry.header)
      entry.header.remove()
    })
  }
}
