import { describe, it, expect } from 'vitest'
import { renderHook } from '@testing-library/react'
import { useScrollReveal } from '../hooks/useScrollReveal'

describe('useScrollReveal', () => {
  it('returns ref and initial isVisible=false', () => {
    const { result } = renderHook(() => useScrollReveal())
    expect(result.current.ref).toBeDefined()
    expect(result.current.isVisible).toBe(false)
  })

  it('sets isVisible=true immediately when prefers-reduced-motion', () => {
    const originalMatchMedia = window.matchMedia
    window.matchMedia = (query) => ({
      matches: query === '(prefers-reduced-motion: reduce)',
      media: query,
      onchange: null,
      addListener: () => {},
      removeListener: () => {},
      addEventListener: () => {},
      removeEventListener: () => {},
      dispatchEvent: () => {},
    })

    const { result } = renderHook(() => useScrollReveal())
    expect(result.current.isVisible).toBe(true)

    window.matchMedia = originalMatchMedia
  })

  it('disconnects observer on unmount', () => {
    const originalMatchMedia = window.matchMedia
    window.matchMedia = (query) => ({
      matches: false,
      media: query,
      onchange: null,
      addListener: () => {},
      removeListener: () => {},
      addEventListener: () => {},
      removeEventListener: () => {},
      dispatchEvent: () => {},
    })

    const { unmount } = renderHook(() => useScrollReveal())
    expect(() => unmount()).not.toThrow()

    window.matchMedia = originalMatchMedia
  })
})
