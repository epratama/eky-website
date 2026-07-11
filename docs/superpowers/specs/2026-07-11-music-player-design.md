# Music Player Design (v5)

## Problem

Single-page portfolio resumes are static — no ambient interaction. A unobtrusive
music player adds personality without needing a separate page or routing change.

## Scope

One new component (`MusicPlayer.jsx`), one line in `App.jsx`, one CSP addition
in `index.html`, 14 tests in a new test file. No new dependencies (SoundCloud
Widget API loaded dynamically via `<script async>`). No npm deps added (Lucide
icons already installed).

## Design

### Track

**"Healing Velvet Wind (lofi jazz)"** by Purple LoFi Beats — royalty-free lofi
jazz track, ~3 min, ideal for ambient background. SoundCloud public track URL:
`https://w.soundcloud.com/player/?url=https%3A%2F%2Fapi.soundcloud.com%2Ftracks%2F2093689164&color=%232563EB&auto_play=true&hide_related=true&show_comments=false&show_user=false&show_reposts=false&show_teaser=false`

### 5-State Machine

```
idle → loading → playing → paused → finished
        ↑         ↓         ↓
        └─────────┴─────────┘
```

| State | Visual | Buttons Active |
|-------|--------|----------------|
| `idle` | Static play button | Play |
| `loading` | Spinner (Loader2 animate-spin) | None |
| `playing` | Pause button | Pause, Stop |
| `paused` | Play button | Play, Stop |
| `finished` | Play button (restart) | Play |

### Architecture

- Hidden `<iframe>` (SoundCloud Widget API) — positioned off-screen, not
  `display:none` (Widget API needs rendered dimensions).
- `aria-hidden="true"` on the iframe — screen readers skip it.
- Custom neo-brutalist controls overlaid below: PlayCircle, PauseCircle,
  StopCircle from Lucide (all `w-6 h-6` for consistent icon sizing).
- Dynamic `<script async>` injection for Widget API (`window.SC`).
- Null guard in `script.onload`: `if (!iframeRef.current) return` — prevents
  null ref on fast unmount.
- Cleanup on unmount: `widget.destroy()`, iframe removal, script tag removal
  from DOM.
- `referrerpolicy="no-referrer"` on iframe.
- `aria-live="polite"` status region with `sr-only` text per state.
- 48px minimum touch targets (Tailwind `min-w-[48px] min-h-[48px]`).
- `prefers-reduced-motion` media query disables `animate-spin` on Loader2
  (static dot instead).

### Placement

Interstitial between ContactForm and BuildShowcase in `App.jsx`. Unnumbered
(no "07" label), no navbar entry. Uses same SectionTitle component but without
the number prop.

### CSP

Add `w.soundcloud.com` to `script-src` and `frame-src`:

```
script-src 'self' https://w.soundcloud.com ... ;
frame-src https://w.soundcloud.com https://hcaptcha.com ... ;
```

### CSS

No new CSS beyond Tailwind utility classes. The component is self-contained
with inline Tailwind classes matching the neo-brutalist design system (border
`border-[3px] border-brutal-primary`, shadow `shadow-brutal`, bg `bg-white`,
text `text-brutal-primary`, accent `bg-brutal-accent`).

### Accessibility

| Element | Attribute | Value |
|---------|-----------|-------|
| iframe | `aria-hidden` | `true` |
| Container | `role` | `region` |
| Container | `aria-label` | "Music player" |
| Buttons | `aria-label` | "Play music", "Pause music", "Stop music" |
| Status | `aria-live` | `polite` |
| Status text | class | `sr-only` |

## 14 Tests

### Phase 1 — Component logic (10 tests)

| # | Test | Lines |
|---|------|-------|
| T1 | Renders play button in idle state | 3 |
| T2 | Clicking play sets loading state | 3 |
| T3 | Transitions from loading to playing after script loads | 4 |
| T4 | Pause button works from playing state | 4 |
| T5 | Stop button works from playing state (returns to idle) | 4 |
| T6 | Stop button works from paused state (returns to idle) | 4 |
| T7 | Play from finished state restarts track | 4 |
| T8 | SoundCloud script injected when play clicked | 5 |
| T9 | Widget API calls play/pause/stop correctly | 5 |
| T10 | Cleanup on unmount destroys widget and removes iframe | 5 |

### Phase 2 — Edge cases + accessibility (4 tests)

| # | Test | Lines |
|---|------|-------|
| T11 | aria-live region updates with correct state text | 3 |
| T12 | 48px min touch targets on all buttons | 3 |
| T13 | `<script>` tag removed from DOM on unmount | 2 |
| T14 | `prefers-reduced-motion` → static dot, no `animate-spin` | 2 |

## Advisories Applied (v4 → v5)

| ID | Source | Change |
|----|--------|--------|
| A1 | Security audit | iframe gets `aria-hidden="true"` |
| A2 | Engineering audit | `onload` guard: `if (!iframeRef.current) return` |
| A3 | ui-ux-pro-max | Icons: `w-6 h-6` (24px) for consistency |
| T13 | TDD audit | Test: `<script>` tag removed from DOM on unmount |
| T14 | TDD audit | Test: `prefers-reduced-motion` → static dot |

## Audit Results

| Audit | Verdict |
|-------|---------|
| MoA (5 agents) | **PASS** — 0 remaining advisories |
| Spec Review | **Approved** |
| TDD (14 tests) | **PASS** |
| ui-ux-pro-max | **Approved** |

All 4 audits green.

## Getting Started

```bash
# create component
touch frontend/src/components/MusicPlayer.jsx

# create test file
touch frontend/src/__tests__/MusicPlayer.test.jsx

# run tests
npm -C frontend test -- MusicPlayer.test.jsx

# run all tests
npm -C frontend test

# manual check in dev
npm -C frontend run dev
```
