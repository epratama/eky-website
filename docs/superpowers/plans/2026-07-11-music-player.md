# Music Player Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an unobtrusive lofi jazz music player (SoundCloud Widget API, 5-state machine) between ContactForm and BuildShowcase.

**Architecture:** New `MusicPlayer.jsx` component with hidden SoundCloud iframe, dynamic `<script async>` injection for Widget API, custom neo-brutalist Lucide icon controls, 5-state machine (idle/loading/playing/paused/finished), accessibility via `aria-live` + `aria-label` + `sr-only`. No new npm dependencies.

**Tech Stack:** React 18, Tailwind CSS 3, Lucide React (already installed), SoundCloud Widget API (loaded via dynamic script)

## Global Constraints

- No new npm dependencies — Lucide icons already installed (`lucide-react@^0.468.0`)
- SoundCloud Widget API loaded via dynamic `<script async>` injection (not npm)
- iframe uses `referrerpolicy="no-referrer"` and `aria-hidden="true"`
- All buttons: 48px min touch targets (`min-w-[48px] min-h-[48px]`)
- All buttons: Lucide icons at `w-6 h-6` (24px)
- `prefers-reduced-motion` disables `animate-spin` (static dot instead)
- Cleanup on unmount: widget.destroy(), iframe removal, script tag removal from DOM
- Transition from idle to playing requires explicit click (no autoplay on load)
- onClick handler guards: skip if already playing/loading (prevent double-injection)
- Null guard on iframeRef.current in script.onload to prevent race on fast unmount

## Spec Reference

`docs/superpowers/specs/2026-07-11-music-player-design.md` (v5, 4 audits approved)

---

### Task 1: Update CSP for SoundCloud

**Files:**
- Modify: `frontend/index.html:32` (CSP meta tag)
- Test: `frontend/src/__tests__/App.test.jsx` (extend CSP test)

**Interfaces:**
- Consumes: current CSP from `index.html:32`
- Produces: updated CSP with `https://w.soundcloud.com` in `script-src` and `frame-src`

- [ ] **Step 1: Add w.soundcloud.com to CSP**

Edit `frontend/index.html` — add `https://w.soundcloud.com` to both `script-src` and
`frame-src` directives.

Current `script-src`:
```
script-src 'self' https://hcaptcha.com https://*.hcaptcha.com https://www.googletagmanager.com 'sha256-IcDlT8t4S4FyjOYZEKg5fy31IM1FUzZGl4rhT2zPVw8=';
```

Change to:
```
script-src 'self' https://w.soundcloud.com https://hcaptcha.com https://*.hcaptcha.com https://www.googletagmanager.com 'sha256-IcDlT8t4S4FyjOYZEKg5fy31IM1FUzZGl4rhT2zPVw8=';
```

Current `frame-src`:
```
frame-src https://hcaptcha.com https://*.hcaptcha.com;
```

Change to:
```
frame-src https://w.soundcloud.com https://hcaptcha.com https://*.hcaptcha.com;
```

- [ ] **Step 2: Extend CSP test**

Edit `frontend/src/__tests__/App.test.jsx` — inside the existing CSP test (`CSP allows favicon
data URI`), add two assertions before the closing `})`:

```js
    expect(csp).toContain('w.soundcloud.com')
    expect(csp.match(/script-src[^;]*w\.soundcloud\.com/)).toBeTruthy()
    expect(csp.match(/frame-src[^;]*w\.soundcloud\.com/)).toBeTruthy()
```

- [ ] **Step 3: Run the test to verify**

Run: `npm -C frontend test -- App.test.jsx`
Expected: 7 tests in App test suite, all PASS

- [ ] **Step 4: Commit**

```bash
git add frontend/index.html frontend/src/__tests__/App.test.jsx
git commit -m "feat: add w.soundcloud.com to CSP for music player"
```

---

### Task 2: Create MusicPlayer Component + Full Tests

**Files:**
- Create: `frontend/src/components/MusicPlayer.jsx`
- Create: `frontend/src/__tests__/MusicPlayer.test.jsx`
- Modify: `frontend/src/components/App.jsx` (import + placement)

**Interfaces:**
- Produces: `<MusicPlayer />` component (no props, self-contained)

- [ ] **Step 1: Write the failing tests**

Create `frontend/src/__tests__/MusicPlayer.test.jsx`:

```jsx
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm -C frontend test -- MusicPlayer.test.jsx`
Expected: FAIL with "Cannot find module '../components/MusicPlayer'"

- [ ] **Step 3: Create MusicPlayer.jsx**

Create `frontend/src/components/MusicPlayer.jsx`:

```jsx
import { useState, useRef, useEffect, useCallback } from 'react'
import { PlayCircle, PauseCircle, StopCircle, Loader2 } from 'lucide-react'

const TRACK_URL =
  'https://w.soundcloud.com/player/?url=https%3A%2F%2Fapi.soundcloud.com%2Ftracks%2F2093689164&color=%232563EB&auto_play=true&hide_related=true&show_comments=false&show_user=false&show_reposts=false&show_teaser=false'

const WIDGET_SCRIPT = 'https://w.soundcloud.com/player/api.js'

function prefersReducedMotion() {
  return window.matchMedia('(prefers-reduced-motion: reduce)').matches
}

export default function MusicPlayer() {
  const [state, setState] = useState('idle')
  const iframeRef = useRef(null)
  const widgetRef = useRef(null)
  const scriptRef = useRef(null)

  const statusText = {
    idle: 'Music player is idle',
    loading: 'Loading music',
    playing: 'Music is playing',
    paused: 'Music is paused',
    finished: 'Music has finished',
  }

  useEffect(() => {
    return () => {
      if (widgetRef.current) widgetRef.current.destroy()
      if (iframeRef.current && iframeRef.current.parentNode) {
        iframeRef.current.parentNode.removeChild(iframeRef.current)
      }
      if (scriptRef.current && scriptRef.current.parentNode) {
        scriptRef.current.parentNode.removeChild(scriptRef.current)
      }
    }
  }, [])

  const handlePlay = useCallback(() => {
    if (state === 'playing' || state === 'loading') return
    setState('loading')

    if (window.SC && widgetRef.current) {
      widgetRef.current.play()
      setState('playing')
      return
    }

    const script = document.createElement('script')
    script.src = WIDGET_SCRIPT
    script.async = true
    scriptRef.current = script

    script.onload = () => {
      if (!iframeRef.current) return

      const widget = window.SC.Widget(iframeRef.current)
      widgetRef.current = widget
      widget.bind(window.SC.Widget.Events.PLAY, () => setState('playing'))
      widget.bind(window.SC.Widget.Events.PAUSE, () => setState('paused'))
      widget.bind(window.SC.Widget.Events.FINISH, () => setState('finished'))
      widget.play()
      setState('playing')
    }

    document.head.appendChild(script)
  }, [state])

  const handlePause = useCallback(() => {
    if (widgetRef.current) {
      widgetRef.current.pause()
      setState('paused')
    }
  }, [])

  const handleStop = useCallback(() => {
    if (widgetRef.current) {
      widgetRef.current.stop()
      setState('idle')
    }
  }, [])

  const spinner = prefersReducedMotion() ? '' : 'animate-spin'

  return (
    <section
      role="region"
      aria-label="Music player"
      className="py-12 px-6 bg-white border-t-[3px] border-brutal-primary"
    >
      <div className="mx-auto max-w-4xl flex flex-col items-center gap-4">
        <iframe
          ref={iframeRef}
          title="SoundCloud music player"
          aria-hidden="true"
          src={TRACK_URL}
          width="1"
          height="1"
          className="absolute -left-[9999px] -top-[9999px]"
          referrerpolicy="no-referrer"
        />

        <div className="flex items-center gap-4">
          {state === 'loading' ? (
            <button
              aria-label="Loading"
              disabled
              className="flex items-center justify-center min-w-[48px] min-h-[48px] border-[3px] border-brutal-primary bg-brutal-primary text-brutal-bg cursor-not-allowed"
            >
              <Loader2 size={24} className={`w-6 h-6 ${spinner}`} />
            </button>
          ) : (
            <button
              aria-label={
                state === 'paused' || state === 'finished' || state === 'idle'
                  ? 'Play music'
                  : 'Pause music'
              }
              onClick={state === 'playing' ? handlePause : handlePlay}
              className="flex items-center justify-center min-w-[48px] min-h-[48px] border-[3px] border-brutal-primary bg-brutal-primary text-brutal-bg hover:bg-brutal-bg hover:text-brutal-primary cursor-pointer transition-colors duration-150"
            >
              {state === 'playing' ? (
                <PauseCircle size={24} className="w-6 h-6" />
              ) : (
                <PlayCircle size={24} className="w-6 h-6" />
              )}
            </button>
          )}

          {(state === 'playing' || state === 'paused') && (
            <button
              aria-label="Stop music"
              onClick={handleStop}
              className="flex items-center justify-center min-w-[48px] min-h-[48px] border-[3px] border-brutal-primary bg-white text-brutal-primary hover:bg-brutal-primary hover:text-brutal-bg cursor-pointer transition-colors duration-150"
            >
              <StopCircle size={24} className="w-6 h-6" />
            </button>
          )}
        </div>

        <p aria-live="polite" className="sr-only">
          {statusText[state]}
        </p>
      </div>
    </section>
  )
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm -C frontend test -- MusicPlayer.test.jsx`
Expected: 14 tests, all PASS

**If any test fails:** STOP. Read the failure, fix the test or implementation, re-run.

- [ ] **Step 5: Wire MusicPlayer into App.jsx**

Edit `frontend/src/components/App.jsx` — add import and element between ContactForm and
BuildShowcase:

Add import at line 10 (after ContactForm import):
```jsx
import MusicPlayer from './MusicPlayer'
```

Add element at line 24 (after `<ContactForm />`):
```jsx
      <MusicPlayer />
```

Resulting file:
```jsx
import resume from '../data/resume.json'
import Navbar from './Navbar'
import Hero from './Hero'
import Summary from './Summary'
import KeyAchievements from './KeyAchievements'
import Experience from './Experience'
import Skills from './Skills'
import Education from './Education'
import ContactForm from './ContactForm'
import MusicPlayer from './MusicPlayer'
import BuildShowcase from './BuildShowcase'
import Footer from './Footer'

export default function App() {
  return (
    <div className="min-h-screen bg-brutal-bg text-brutal-text font-body">
      <Navbar />
      <Hero data={resume} />
      <Summary summary={resume.summary} />
      <KeyAchievements achievements={resume.keyAchievements} />
      <Experience experience={resume.experience} />
      <Skills skills={resume.skills} />
      <Education education={resume.education} certifications={resume.certifications} />
      <ContactForm />
      <MusicPlayer />
      <BuildShowcase repo={resume.repo} />
      <Footer name={resume.name} role={resume.title} linkedin={resume.linkedin} github={resume.github} />
    </div>
  )
}
```

- [ ] **Step 6: Run full frontend test suite**

Run: `npm -C frontend test`
Expected: 22 tests (7 App + 14 MusicPlayer + 1 ContactForm... actually let me count existing:
App.test.jsx has 7 `it` blocks, ContactForm.test.jsx has 4, useScrollReveal.test.jsx... let me check)

Run: `npx vitest run --reporter=verbose` (from frontend/)
Expected: All tests PASS. Verify no regressions in existing test suites.

- [ ] **Step 7: Commit**

```bash
git add frontend/src/components/MusicPlayer.jsx frontend/src/__tests__/MusicPlayer.test.jsx frontend/src/components/App.jsx
git commit -m "feat: add music player with SoundCloud Widget API

New MusicPlayer component with 5-state machine (idle/loading/playing/paused/finished),
hidden SoundCloud iframe, dynamic script injection for Widget API, neo-brutalist
Lucide icon controls, 48px touch targets, aria-live status region, prefers-reduced-motion
support. 14 TDD tests pass. Placed between ContactForm and BuildShowcase."
```

---

### Task 3: Full Test Suite + Build Verification

**Files:**
- Test: all 4 test suites (frontend vitest, backend pytest, deploy bash, template bash)
- Build: `npm -C frontend run build`

- [ ] **Step 1: Run frontend tests**

```bash
npm -C frontend test
```
Expected: all tests PASS. Count should be: 7 (App) + 14 (MusicPlayer) + 4 (ContactForm) + 2 (useScrollReveal) = 27.

- [ ] **Step 2: Run backend tests**

```bash
python3 -m pytest backend/test_lambda.py -q
```
Expected: 29 tests, all PASS.

- [ ] **Step 3: Run deploy tests**

```bash
bash tests/test_deploy.sh
```
Expected: 13 tests, all PASS.

- [ ] **Step 4: Run template tests**

```bash
bash tests/test_template.sh
```
Expected: 17 tests, all PASS.

- [ ] **Step 5: Production build**

```bash
npm -C frontend run build
```
Expected: build succeeds. Verify dist/assets/ contains JS and CSS bundles.

- [ ] **Step 6: Spot-check built index.html has updated CSP**

```bash
grep -c 'w.soundcloud.com' frontend/dist/index.html
```
Expected: 2 (once in script-src, once in frame-src)

- [ ] **Step 7: Commit (if any test/build files were updated)**

```bash
git add -A
git diff --cached --stat
# Commit only if files were modified
```

---

## Failure Protocol

At ANY step that fails (tests, build, scan, review):

1. **STOP.** Do not continue to next task.
2. Invoke `superpowers:systematic-debugging` to find root cause
3. Apply fix
4. Re-run the failed step
5. If the fix changes code written in Tasks 1-2:
   - Re-run Task 3 (full test suite)
   - Re-run build
6. Resume from where you stopped
