# BuildShowcase + ExperienceCard Redesign — Design Spec

## Problem

1. **ExperienceCard "Show highlights" button** blends into surrounding text — visitors don't notice it's clickable. No visual affordance beyond a chevron icon.

2. **BuildShowcase section** ("How This Site Was Built") sits at the bottom of the page (section 07) with plain text copy. Visitors rarely scroll that far, and the copy doesn't communicate the multi-agent AI value proposition.

## Design

### ExperienceCard — "Show highlights" button

Convert from plain text link to a bordered pill button matching the site's neo-brutalist pattern. Add a one-time glow-ring animation when the card scrolls into view (via the existing `useScrollReveal` hook).

| Before | After |
|--------|-------|
| `text-brutal-accent font-bold text-sm` with chevron | `border-[3px] border-brutal-accent px-4 py-2 text-sm font-bold` pill with chevron + `animate-glow-ring` on scroll reveal |
| `transition-colors duration-150` | `transition-all duration-200` |
| No hover fill | `hover:bg-brutal-accent hover:text-brutal-bg` |
| Chevron static | `transition-transform duration-300` with `rotate-180` on expand |

### BuildShowcase — New copy + animation

Move to position 05 (after Experience, before Skills) for better visibility. New copy communicates the multi-agent AI value proposition. GitHub button gets the same glow-ring animation as the highlights button.

**New section numbering:**
```
01 Hero → 02 Summary → 03 KeyAchievements → 04 Experience → 
05 How It Was Built → 06 Skills → 07 Education → 08 ContactForm
```

**New copy:**
> "Built through Multi-Agent AI Orchestration — with production engineering and security standards."
>
> "See how it's done →"

### Glow-Ring Animation

Shared custom keyframe for both sections:

```css
@keyframes glow-ring {
  0%, 100% { box-shadow: 0 0 0 0 rgba(37, 99, 235, 0.4); }
  50% { box-shadow: 0 0 0 5px rgba(37, 99, 235, 0); }
}

.animate-glow-ring {
  animation: glow-ring 2.5s ease-out 0.5s 1 forwards;
}
```

Applied to buttons when `isVisible` (scroll reveal) triggers. One-time animation — after completion, button is static with standard hover.
Respects `prefers-reduced-motion: reduce` via existing global CSS rule.

## Scope

| File | Change | Lines |
|------|--------|-------|
| `BuildShowcase.jsx` | New copy, glow-ring on button | ~8 |
| `ExperienceCard.jsx` | Bordered pill button, glow-ring trigger | ~6 |
| `App.jsx` | Move BuildShowcase after Experience, renumber sections | ~3 |
| `index.css` | `@keyframes glow-ring` + `.animate-glow-ring` | ~10 |
| `App.test.jsx` | 5 new assertions for position/copy/animation classes | ~15 |
| **Total** | **5 files** | **~42 lines** |

## Tests (5 new assertions)

| # | Test | What |
|---|------|------|
| 1 | BuildShowcase appears after Experience section | DOM order: `#experience` → `#showcase` |
| 2 | BuildShowcase contains new copy text | "Multi-Agent AI Orchestration" present |
| 3 | ExperienceCard highlights button has glow-ring | `animate-glow-ring` class on button in ExperienceCard |
| 4 | BuildShowcase GitHub button exists | Link with GitHub icon + repo URL |
| 5 | BuildShowcase button has glow-ring | `animate-glow-ring` class on GitHub button |

## Design Decisions

- **Glow-ring not continuous:** Per ui-ux-pro-max, infinite animations are distracting. One-time pulse on scroll is more professional.
- **Bordered pill button:** Matches every other CTA on the site (Hero LinkedIn/GitHub, ContactForm submit). Consistency = professional.
- **Section repositioning:** After Experience, not bottom. Narrative flow: see experience → here's how this site was built → see skills — natural progression.
- **`prefers-reduced-motion`:** Already handled globally in `index.css`. No additional work needed.
