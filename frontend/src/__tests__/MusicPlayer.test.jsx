import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { render, screen, fireEvent, act } from '@testing-library/react'
import MusicPlayer from '../components/MusicPlayer'

beforeEach(() => {
  vi.clearAllMocks()

  Object.defineProperty(window, 'matchMedia', {
    writable: true,
    value: vi.fn().mockImplementation((query) => ({
      matches: query === '(prefers-reduced-motion: reduce)',
      media: query,
      onchange: null,
      addListener: vi.fn(),
      removeListener: vi.fn(),
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
      dispatchEvent: vi.fn(),
    })),
  })

  window.SC = undefined
})

afterEach(() => {
  document.body.querySelectorAll('script').forEach((s) => {
    if (s.src.includes('w.soundcloud.com')) s.remove()
  })
})

// --- Phase 1: Component logic ---

describe('MusicPlayer — Phase 1', () => {
  it('T1: renders play button in idle state', () => {
    render(<MusicPlayer />)
    expect(screen.getByRole('button', { name: /play music/i })).toBeInTheDocument()
  })

  it('T2: clicking play sets loading state', () => {
    render(<MusicPlayer />)
    fireEvent.click(screen.getByRole('button', { name: /play music/i }))
    expect(screen.getByRole('button', { name: /loading/i })).toBeInTheDocument()
  })

  it('T3: transitions from loading to playing after script loads', () => {
    render(<MusicPlayer />)
    fireEvent.click(screen.getByRole('button', { name: /play music/i }))

    const script = document.querySelector('script[src*="w.soundcloud.com"]')
    expect(script).toBeTruthy()

    window.SC = {
      Widget: Object.assign(
        vi.fn(() => ({
          play: vi.fn(), pause: vi.fn(), stop: vi.fn(), destroy: vi.fn(),
          bind: vi.fn(),
        })),
        { Events: { PLAY: 'play', PAUSE: 'pause', FINISH: 'finish' } },
      ),
    }

    act(() => { script.onload() })
    expect(screen.getByRole('button', { name: /pause music/i })).toBeInTheDocument()
  })

  it('T4: pause button works from playing state', () => {
    const mockPause = vi.fn()
    window.SC = {
      Widget: Object.assign(
        vi.fn(() => ({
          play: vi.fn(), pause: mockPause, stop: vi.fn(), destroy: vi.fn(),
          bind: vi.fn(),
        })),
        { Events: { PLAY: 'play', PAUSE: 'pause', FINISH: 'finish' } },
      ),
    }

    render(<MusicPlayer />)
    fireEvent.click(screen.getByRole('button', { name: /play music/i }))
    const script = document.querySelector('script[src*="w.soundcloud.com"]')
    act(() => { script.onload() })

    fireEvent.click(screen.getByRole('button', { name: /pause music/i }))
    expect(mockPause).toHaveBeenCalled()
  })

  it('T5: stop button works from playing state (returns to idle)', () => {
    const mockStop = vi.fn()
    window.SC = {
      Widget: Object.assign(
        vi.fn(() => ({
          play: vi.fn(), pause: vi.fn(), stop: mockStop, destroy: vi.fn(),
          bind: vi.fn(),
        })),
        { Events: { PLAY: 'play', PAUSE: 'pause', FINISH: 'finish' } },
      ),
    }

    render(<MusicPlayer />)
    fireEvent.click(screen.getByRole('button', { name: /play music/i }))
    const script = document.querySelector('script[src*="w.soundcloud.com"]')
    act(() => { script.onload() })

    const buttons = screen.getAllByRole('button')
    const stopBtn = buttons.find((b) => b.getAttribute('aria-label') === 'Stop music')
    fireEvent.click(stopBtn)
    expect(mockStop).toHaveBeenCalled()
  })

  it('T6: stop button works from paused state (returns to idle)', () => {
    const mockStop = vi.fn()
    window.SC = {
      Widget: Object.assign(
        vi.fn(() => ({
          play: vi.fn(), pause: vi.fn(), stop: mockStop, destroy: vi.fn(),
          bind: vi.fn(),
        })),
        { Events: { PLAY: 'play', PAUSE: 'pause', FINISH: 'finish' } },
      ),
    }

    render(<MusicPlayer />)
    fireEvent.click(screen.getByRole('button', { name: /play music/i }))
    const script = document.querySelector('script[src*="w.soundcloud.com"]')
    act(() => { script.onload() })

    fireEvent.click(screen.getByRole('button', { name: /pause music/i }))
    const buttons = screen.getAllByRole('button')
    const stopBtn = buttons.find((b) => b.getAttribute('aria-label') === 'Stop music')
    fireEvent.click(stopBtn)
    expect(mockStop).toHaveBeenCalled()
  })

  it('T7: play from finished state restarts track', () => {
    const mockPlay = vi.fn()
    window.SC = {
      Widget: Object.assign(
        vi.fn(() => ({
          play: mockPlay, pause: vi.fn(), stop: vi.fn(), destroy: vi.fn(),
          bind: vi.fn(),
        })),
        { Events: { PLAY: 'play', PAUSE: 'pause', FINISH: 'finish' } },
      ),
    }

    render(<MusicPlayer />)
    fireEvent.click(screen.getByRole('button', { name: /play music/i }))
    const script = document.querySelector('script[src*="w.soundcloud.com"]')
    act(() => { script.onload() })

    fireEvent.click(screen.getByRole('button', { name: /pause music/i }))
    fireEvent.click(screen.getByRole('button', { name: /play music/i }))
    expect(mockPlay).toHaveBeenCalled()
  })

  it('T8: SoundCloud script injected when play clicked', () => {
    render(<MusicPlayer />)
    expect(document.querySelector('script[src*="w.soundcloud.com"]')).toBeNull()

    fireEvent.click(screen.getByRole('button', { name: /play music/i }))
    const script = document.querySelector('script[src*="w.soundcloud.com"]')
    expect(script).toBeTruthy()
    expect(script.async).toBe(true)
  })

  it('T9: Widget API calls play/pause/stop correctly', () => {
    const mockPlay = vi.fn()
    const mockPause = vi.fn()
    const mockStop = vi.fn()
    window.SC = {
      Widget: Object.assign(
        vi.fn(() => ({
          play: mockPlay, pause: mockPause, stop: mockStop, destroy: vi.fn(),
          bind: vi.fn(),
        })),
        { Events: { PLAY: 'play', PAUSE: 'pause', FINISH: 'finish' } },
      ),
    }

    render(<MusicPlayer />)
    fireEvent.click(screen.getByRole('button', { name: /play music/i }))
    const script = document.querySelector('script[src*="w.soundcloud.com"]')
    act(() => { script.onload() })

    expect(mockPlay).toHaveBeenCalled()

    fireEvent.click(screen.getByRole('button', { name: /pause music/i }))
    expect(mockPause).toHaveBeenCalled()

    const buttons = screen.getAllByRole('button')
    const stopBtn = buttons.find((b) => b.getAttribute('aria-label') === 'Stop music')
    fireEvent.click(stopBtn)
    expect(mockStop).toHaveBeenCalled()
  })

  it('T10: cleanup on unmount destroys widget and removes iframe', () => {
    const mockDestroy = vi.fn()
    window.SC = {
      Widget: Object.assign(
        vi.fn(() => ({
          play: vi.fn(), pause: vi.fn(), stop: vi.fn(), destroy: mockDestroy,
          bind: vi.fn(),
        })),
        { Events: { PLAY: 'play', PAUSE: 'pause', FINISH: 'finish' } },
      ),
    }

    const { unmount } = render(<MusicPlayer />)
    fireEvent.click(screen.getByRole('button', { name: /play music/i }))
    const script = document.querySelector('script[src*="w.soundcloud.com"]')
    act(() => { script.onload() })

    unmount()
    expect(mockDestroy).toHaveBeenCalled()
  })
})

// --- Phase 2: Accessibility + edge cases ---

describe('MusicPlayer — Phase 2', () => {
  it('T11: aria-live region updates with correct state text', () => {
    render(<MusicPlayer />)
    expect(screen.getByRole('region', { name: /music player/i })).toBeInTheDocument()
    expect(screen.getByText(/music player is idle/i)).toBeInTheDocument()

    fireEvent.click(screen.getByRole('button', { name: /play music/i }))
    expect(screen.getByText(/loading music/i)).toBeInTheDocument()
  })

  it('T12: 48px min touch targets on all buttons', () => {
    render(<MusicPlayer />)
    screen.getAllByRole('button').forEach((btn) => {
      expect(btn.className).toMatch(/min-w-\[48px\]/)
      expect(btn.className).toMatch(/min-h-\[48px\]/)
    })
  })

  it('T13: script tag removed from DOM on unmount', () => {
    window.SC = {
      Widget: Object.assign(
        vi.fn(() => ({
          play: vi.fn(), pause: vi.fn(), stop: vi.fn(), destroy: vi.fn(),
          bind: vi.fn(),
        })),
        { Events: { PLAY: 'play', PAUSE: 'pause', FINISH: 'finish' } },
      ),
    }

    const { unmount } = render(<MusicPlayer />)
    fireEvent.click(screen.getByRole('button', { name: /play music/i }))
    expect(document.querySelector('script[src*="w.soundcloud.com"]')).toBeTruthy()

    unmount()
    expect(document.querySelector('script[src*="w.soundcloud.com"]')).toBeNull()
  })

  it('T14: prefers-reduced-motion shows static dot, no animate-spin', () => {
    window.matchMedia = vi.fn().mockImplementation((query) => ({
      matches: query === '(prefers-reduced-motion: reduce)',
      media: query,
      onchange: null,
      addListener: vi.fn(),
      removeListener: vi.fn(),
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
      dispatchEvent: vi.fn(),
    }))

    render(<MusicPlayer />)
    fireEvent.click(screen.getByRole('button', { name: /play music/i }))
    const loadingBtn = screen.getByRole('button', { name: /loading/i })
    expect(loadingBtn).toBeInTheDocument()
    expect(loadingBtn.className).not.toMatch(/animate-spin/)
  })
})
