import '@testing-library/jest-dom'

global.IntersectionObserver = class IntersectionObserver {
  constructor(callback) {
    this.callback = callback
    this.elements = new Set()
  }
  observe(el) { this.elements.add(el) }
  unobserve(el) { this.elements.delete(el) }
  disconnect() { this.elements.clear() }
  trigger(entries) { this.callback(entries, this) }
}

Object.defineProperty(window, 'matchMedia', {
  writable: true,
  value: (query) => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: () => {},
    removeListener: () => {},
    addEventListener: () => {},
    removeEventListener: () => {},
    dispatchEvent: () => {},
  }),
})
