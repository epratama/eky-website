# BuildShowcase + ExperienceCard Redesign — Implementation Plan

> **For agentic workers:** Follow TDD workflow. Write failing tests first, then implement, then verify.

**Goal:** Redesign "Show highlights" button as bordered pill with glow-ring animation, reposition BuildShowcase with new copy + animation, move section higher on page.

**Architecture:** Shared `animate-glow-ring` CSS class applied to both buttons via `useScrollReveal` `isVisible` trigger. One-time pulse animation on scroll revelation.

**Tech Stack:** React 18, Tailwind CSS 3, Lucide React

## Global Constraints

- Respect `prefers-reduced-motion: reduce` (already handled globally in `index.css`)
- Match existing neo-brutalist border pattern: `border-[3px]`
- Use existing `useScrollReveal` hook for animation triggers
- Section numbering must be sequential (01-08)

## Spec Reference

`docs/superpowers/specs/2026-07-12-build-showcase-redesign.md`

---

### Task 1: TDD — Add Tests (RED)

**Files:**
- Modify: `frontend/src/__tests__/App.test.jsx`

- [ ] **Step 1: Add 5 new assertions to existing App test suite**

Add after the existing `renders the build showcase section` test (and update the existing test text for new copy):

```jsx
  it('renders BuildShowcase with new copy text', () => {
    render(<App />)
    expect(screen.getByText(/Multi-Agent AI/i)).toBeInTheDocument()
    expect(screen.getByText(/See how it's done/i)).toBeInTheDocument()
  })

  it('renders BuildShowcase between Experience and Skills', () => {
    render(<App />)
    const sections = Array.from(document.querySelectorAll('section[id]'))
    const showcaseIdx = sections.findIndex(s => s.id === 'showcase')
    const experienceIdx = sections.findIndex(s => s.id === 'experience')
    const skillsIdx = sections.findIndex(s => s.id === 'skills')
    expect(showcaseIdx).toBeGreaterThan(experienceIdx)
    expect(showcaseIdx).toBeLessThan(skillsIdx)
  })

  it('renders ExperienceCard highlights button with glow-ring class', () => {
    render(<App />)
    const buttons = screen.getAllByRole('button', { name: /show highlights/i })
    expect(buttons.length).toBeGreaterThan(0)
    expect(buttons[0].className).toMatch(/animate-glow-ring/)
  })
```

- [ ] **Step 2: Run tests to verify they FAIL**

```bash
npm -C frontend test
```
Expected: 3+ assertions FAIL — "Multi-Agent AI" not found, glow-ring class not present, BuildShowcase still at old position.

---

### Task 2: Add CSS Keyframes

**Files:**
- Modify: `frontend/src/index.css`

- [ ] **Step 1: Add glow-ring keyframes before the closing `}`**

After line 34 (closing `}`), before line 35 (`}` — the `@layer base` closing brace), add:

```css

  @keyframes glow-ring {
    0%, 100% { box-shadow: 0 0 0 0 rgba(37, 99, 235, 0.4); }
    50% { box-shadow: 0 0 0 5px rgba(37, 99, 235, 0); }
  }

  .animate-glow-ring {
    animation: glow-ring 2.5s ease-out 0.5s 1 forwards;
  }
```

- [ ] **Step 2: Verify CSS compiles**

```bash
npm -C frontend run build
```
Expected: Build succeeds, no CSS errors.

---

### Task 3: Update ExperienceCard.jsx

**Files:**
- Modify: `frontend/src/components/ExperienceCard.jsx`

- [ ] **Step 1: Replace the highlights button (lines 38-45)**

Replace the current button with:

```jsx
        <button
          onClick={() => setExpanded(!expanded)}
          className={`group inline-flex items-center gap-2 border-[3px] border-brutal-accent px-4 py-2 font-body text-sm font-bold text-brutal-accent cursor-pointer transition-all duration-200 hover:bg-brutal-accent hover:text-brutal-bg ${isVisible && !expanded ? 'animate-glow-ring' : ''}`}
          aria-expanded={expanded}
        >
          <ChevronDown
            size={16}
            className={`transition-transform duration-300 ${expanded ? 'rotate-180' : 'group-hover:translate-y-0.5'}`}
          />
          {expanded ? 'Show less' : `Show highlights (${role.highlights?.length ?? 0})`}
        </button>
```

- [ ] **Step 2: Verify render**

```bash
npm -C frontend test
```
Expected: Old test failures + new test for glow-ring class should still FAIL (test expects class, but implementation is now correct).

---

### Task 4: Update BuildShowcase.jsx

**Files:**
- Modify: `frontend/src/components/BuildShowcase.jsx`

- [ ] **Step 1: Replace the component body**

Replace the entire card content with:

```jsx
import { Github } from 'lucide-react'
import SectionTitle from './SectionTitle'
import { useScrollReveal } from '../hooks/useScrollReveal'

export default function BuildShowcase({ repo }) {
  const { ref, isVisible } = useScrollReveal()

  return (
    <section id="showcase" className="py-20 px-6">
      <div className="mx-auto max-w-4xl">
        <SectionTitle number="05" title="How This Site Was Built" />

        <div
          ref={ref}
          className={`border-[3px] border-brutal-primary bg-white shadow-brutal p-6 md:p-10 transition-all duration-400 ${
            isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-8'
          }`}
        >
          <div className="flex flex-col gap-6">
            <div className="flex flex-col gap-3">
              <p className="font-body text-base md:text-lg font-medium text-brutal-primary leading-relaxed">
                Built through <span className="font-bold text-brutal-accent">Multi-Agent AI Orchestration</span> — with production engineering and security standards.
              </p>
              <p className="font-body text-sm text-brutal-muted">
                See how it's done →
              </p>
            </div>
            <a
              href={repo}
              target="_blank"
              rel="noopener noreferrer"
              className={`inline-flex items-center gap-2 border-[3px] border-brutal-primary px-5 py-2.5 font-body font-bold text-sm text-brutal-primary hover:bg-brutal-primary hover:text-brutal-bg cursor-pointer transition-all duration-200 ${isVisible ? 'animate-glow-ring' : ''}`}
            >
              <Github size={18} />
              See the code on GitHub →
            </a>
          </div>
        </div>
      </div>
    </section>
  )
}
```

**Key changes:**
- Section number: `07` → `05`
- Copy: "Multi-Agent AI Orchestration" + "See how it's done →"
- Button: glow-ring animation on scroll reveal
- Removed: accent bar div (no longer needed with new layout)

- [ ] **Step 2: Verify with test**

```bash
npm -C frontend test
```
Expected: "renders build showcase" test updated to check for new copy.

---

### Task 5: Update App.jsx — Section Ordering

**Files:**
- Modify: `frontend/src/components/App.jsx`

- [ ] **Step 1: Move BuildShowcase after Experience, update section numbers**

Current:
```jsx
      <Experience experience={resume.experience} />
      <Skills skills={resume.skills} />
      <Education education={resume.education} certifications={resume.certifications} />
      <ContactForm />
      <BuildShowcase repo={resume.repo} />
```

Replace with:
```jsx
      <Experience experience={resume.experience} />
      <BuildShowcase repo={resume.repo} />
      <Skills skills={resume.skills} />
      <Education education={resume.education} certifications={resume.certifications} />
      <ContactForm />
```

- [ ] **Step 2: Update SectionTitle numbers in component files**

Skills.jsx: `number="05"` → `"06"`
Education.jsx: `number="06"` → `"07"`
ContactForm.jsx: `number="06"` → `"08"`

- [ ] **Step 3: Verify all section rendering is correct with new numbering**

```bash
npm -C frontend test
```
Expected: All tests pass with updated section numbering.

---

### Task 6: GREEN Phase — Run Full Test Suite

- [ ] **Step 1: Run frontend tests**

```bash
npm -C frontend test
```
Expected: ~18-20 tests PASS (15 original + 3 new + existing tests may be updated by new copy checks).

- [ ] **Step 2: Run all other tests**

```bash
python3 -m pytest backend/test_lambda.py -q
bash test-deploy.sh
bash test-template.sh
```
Expected: 33 + 19 + 17 = 69 tests PASS.

---

### Task 7: Commit

```bash
git add -A
git commit -m "feat: redesign BuildShowcase + ExperienceCard with glow-ring animations (TDD)

- BuildShowcase: new copy (Multi-Agent AI Orchestration), glow-ring button,
  moved to position 05 (after Experience, before Skills)
- ExperienceCard: bordered pill button for highlights with glow-ring on
  scroll reveal, animated chevron rotation
- Shared: @keyframes glow-ring animation in index.css
- Tests: 5 new assertions for position, copy, animation classes"
git push
```

---

## Failure Protocol

At ANY step that fails:
1. **STOP.** Do not continue.
2. Read the failure, fix the test or implementation.
3. Re-run the failed step.
4. Resume from where you stopped.
