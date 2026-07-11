# SEO, Social Sharing & AI Optimization — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Open Graph / Twitter Card meta tags, JSON-LD structured data, SEO directives, and social share image to enable link previews on social platforms and improve search/AI engine visibility for `ekyputrapratama.com`.

**Architecture:** Four static file changes — `index.html` (meta tags + JSON-LD), `public/robots.txt` (crawler directives), `public/og-image.png` (social share image), `resume.json` (skills fix). No backend, infrastructure, or CSP policy changes needed. Vite copies `public/` to `dist/` root automatically during build.

**Tech Stack:** React 18 + Vite 6 + Tailwind CSS 3, CSP via meta tag, S3 + CloudFront hosting

## Global Constraints

- Domain: `ekyputrapratama.com` (HTTPS only)
- CSP: `script-src 'self' https://hcaptcha.com https://*.hcaptcha.com https://www.googletagmanager.com 'sha256-IcDlT8t4S4FyjOYZEKg5fy31IM1FUzZGl4rhT2zPVw8='` — JSON-LD `<script type="application/ld+json">` is not JavaScript execution, does not trigger CSP `script-src` enforcement in modern browsers
- OG/Twitter image: 1200×630px PNG, dark bg (`#18181B`), EP monogram in blue (`#2563EB`)
- All URLs in meta tags MUST be absolute (`https://ekyputrapratama.com/...`), never relative
- JSON-LD must be valid Schema.org Person type, pass Google Rich Results Test
- SDLC: CodeQL baseline → implement → tests → CodeQL rescan → code review → deploy → post-deploy verification
- Failure protocol: any test/code failure → systematic-debugging → root cause fix → retest → CodeQL rescan → re-review

## Spec Reference

`docs/superpowers/specs/2025-07-11-seo-social-sharing-design.md` (v1.1, consortium-audited)

---

### Task 0: CodeQL + Checkov Baseline Scan

**Files:**
- Scan: entire repository

**Interfaces:**
- Produces: baseline findings (expected: 0 new findings for JS + Python + IaC)

- [ ] **Step 1: Run CodeQL security scan**

```bash
skill: codeql-security-scan
```
Expected: 0 findings for JavaScript and Python. CSRF/SSRF/CORS findings from prior scans are known and risk-accepted — verify no NEW findings.

- [ ] **Step 2: Run Checkov IaC scan**

```bash
skill: checkov-iac-scan
```
Expected: 0 critical/high findings. Verify no new findings from prior scan baseline.

- [ ] **Step 3: Record baseline**

Note: "Baseline established. 0 new findings across CodeQL (JS + Python) and Checkov (CloudFormation)."

- [ ] **Step 4: Commit baseline record (if any new files generated)**

---

### Task 1: Resume Skills Fix

**Files:**
- Modify: `frontend/src/data/resume.json:84-113` (skills array, item 6 "Languages & Frameworks")

**Interfaces:**
- Consumes: none
- Produces: `resume.json` skills array updated — `React.js` and `Python` added to "Languages & Frameworks" items

- [ ] **Step 1: Add React.js and Python to languages/frameworks skill group**

Edit `frontend/src/data/resume.json`, skill group "Languages & Frameworks" (index 6):

Current:
```json
"items": ["PHP", "JavaScript", "Node.js", "jQuery", "CSS/Sass", "Bootstrap", "SurveyJS"]
```

Change to:
```json
"items": ["PHP", "JavaScript", "Node.js", "React.js", "Python", "jQuery", "CSS/Sass", "Bootstrap", "SurveyJS"]
```

- [ ] **Step 2: Run vitest to verify no regression**

```bash
npx vitest run
```
Expected: 15 tests, all PASS. No snapshot failures related to skills rendering.

- [ ] **Step 3: Commit**

```bash
git add frontend/src/data/resume.json
git commit -m "fix: add React.js and Python to Languages & Frameworks skills

React.js is the site's own framework (Vite + React 18). Python is the
Lambda backend language (29 pytest tests). Both were missing from the
displayed skills list."
```

---

### Task 2: Create robots.txt

**Files:**
- Create: `frontend/public/robots.txt`

**Interfaces:**
- Produces: `robots.txt` served at `https://ekyputrapratama.com/robots.txt` (Vite copies `public/` → `dist/` root)

- [ ] **Step 1: Create frontend/public/ directory**

```bash
mkdir -p frontend/public
```

- [ ] **Step 2: Write robots.txt**

Create file `frontend/public/robots.txt`:
```
User-agent: *
Allow: /
Sitemap: https://ekyputrapratama.com/sitemap.xml
```

- [ ] **Step 3: Verify Vite copies robots.txt to dist**

```bash
npm run build
ls dist/robots.txt
```
Expected: `dist/robots.txt` exists with identical content.

- [ ] **Step 4: Commit**

```bash
git add frontend/public/robots.txt
git commit -m "feat: add robots.txt with crawler access rules

Allows all user agents, points to sitemap location. Vite auto-copies
public/ to dist/ root during build."
```

---

### Task 3: Generate Social Share Image

**Files:**
- Create: `frontend/public/og-image.png`
- Create (temporary): `frontend/public/generate-og-image.cjs` (generator script, deleted after use)

**Interfaces:**
- Produces: `og-image.png` (1200×630 PNG) served at `https://ekyputrapratama.com/og-image.png`

**Specs:** Dark background (`#18181B`), centered "EP" text in blue (`#2563EB`), Archivo font, weight 800, large proportional font size. Same visual identity as inline SVG favicon.

- [ ] **Step 1: Write generator script**

Create `frontend/public/generate-og-image.cjs`:

```js
const { createCanvas } = require('canvas');
const fs = require('fs');

const W = 1200;
const H = 630;
const canvas = createCanvas(W, H);
const ctx = canvas.getContext('2d');

ctx.fillStyle = '#18181B';
ctx.fillRect(0, 0, W, H);

ctx.fillStyle = '#2563EB';
ctx.font = 'bold 400px "Archivo", "Helvetica Neue", Arial, sans-serif';
ctx.textAlign = 'center';
ctx.textBaseline = 'middle';
ctx.fillText('EP', W / 2, H / 2);

const buf = canvas.toBuffer('image/png');
fs.writeFileSync('og-image.png', buf);
console.log('og-image.png generated (1200x630)');
```

- [ ] **Step 2: Check if canvas package is available or install via npx**

```bash
node -e "require('canvas')" 2>/dev/null && echo "canvas available" || echo "canvas not available, using npx"
```

If canvas not available:
```bash
npm install --no-save canvas 2>/dev/null || npx canvas --help 2>/dev/null
```

Fallback if canvas fails: use ImageMagick convert.

```bash
# Create SVG first
cat > /tmp/ep-og.svg << 'SVGEOF'
<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630">
  <rect width="1200" height="630" fill="#18181B"/>
  <text x="600" y="355" text-anchor="middle" font-family="Archivo,Helvetica Neue,Arial,sans-serif" font-weight="800" font-size="380" fill="#2563EB">EP</text>
</svg>
SVGEOF
convert -background none -density 300 /tmp/ep-og.svg frontend/public/og-image.png
```

- [ ] **Step 3: Generate the image**

```bash
node frontend/public/generate-og-image.cjs
```

Expected: `og-image.png` created in `frontend/public/`, ~50-150KB.

- [ ] **Step 4: Verify image dimensions and format**

```bash
# macOS
sips -g pixelWidth -g pixelHeight frontend/public/og-image.png
# Expected: pixelWidth: 1200, pixelHeight: 630
```

- [ ] **Step 5: Remove generator script**

```bash
rm frontend/public/generate-og-image.cjs
```

- [ ] **Step 6: Verify Vite copies image to dist**

```bash
npm run build
ls -la dist/og-image.png
```
Expected: `dist/og-image.png` exists.

- [ ] **Step 7: Commit**

```bash
git add frontend/public/og-image.png
git commit -m "feat: add social share image (1200x630 EP monogram PNG)

Same visual identity as the existing inline SVG favicon, scaled for
Open Graph / Twitter Card link preview dimensions."
```

---

### Task 4: Add OG, Twitter Card, and SEO Meta Tags to index.html

**Files:**
- Modify: `frontend/index.html` (add `<meta>` tags + `<link>` tag in `<head>`)

**Interfaces:**
- Consumes: `resume.json` (already present, not modified by this task), `public/og-image.png` (Task 3)
- Produces: `index.html` with OG + Twitter Card + SEO meta tags, canonical link, robots meta, author meta

**Tags to add** (between favicon link and CSP comment, or after CSP meta — order doesn't matter for SEO):

- [ ] **Step 1: Insert OG + Twitter Card + SEO tags in index.html `<head>`**

After the CSP `<meta>` tag (line 8), insert these tags before `<!-- GTM_PLACEHOLDER -->`:

```html
    <!-- Open Graph -->
    <meta property="og:title" content="Eky Pratama — Technical Lead & Senior Software Engineer" />
    <meta property="og:description" content="Technical Lead & Senior Software Engineer with 15+ years of experience in web platforms, cloud architecture, and AI-assisted development. LinkedIn: linkedin.com/in/ekyputrapratama | GitHub: github.com/epratama" />
    <meta property="og:image" content="https://ekyputrapratama.com/og-image.png" />
    <meta property="og:image:secure_url" content="https://ekyputrapratama.com/og-image.png" />
    <meta property="og:image:width" content="1200" />
    <meta property="og:image:height" content="630" />
    <meta property="og:image:type" content="image/png" />
    <meta property="og:image:alt" content="Eky Pratama — EP monogram logo on dark background" />
    <meta property="og:url" content="https://ekyputrapratama.com" />
    <meta property="og:type" content="website" />
    <meta property="og:site_name" content="Eky Pratama" />
    <meta property="og:locale" content="en_AU" />
    <!-- Twitter Card -->
    <meta name="twitter:card" content="summary_large_image" />
    <meta name="twitter:title" content="Eky Pratama — Technical Lead & Senior Software Engineer" />
    <meta name="twitter:description" content="Technical Lead & Senior Software Engineer with 15+ years of experience. LinkedIn: linkedin.com/in/ekyputrapratama | GitHub: github.com/epratama" />
    <meta name="twitter:image" content="https://ekyputrapratama.com/og-image.png" />
    <meta name="twitter:image:alt" content="Eky Pratama — EP monogram logo on dark background" />
    <!-- SEO -->
    <link rel="canonical" href="https://ekyputrapratama.com" />
    <meta name="robots" content="index, follow" />
    <meta name="author" content="Eky Pratama" />
```

**Placement:** Insert as contiguous block. Recommended position: between the CSP meta tag and the GTM placeholder comment for readability.

Existing structure:
```html
    <meta http-equiv="Content-Security-Policy" content="..." />   <!-- line 8 -->
    <link rel="icon" href="data:image/svg+xml,...">               <!-- line 9 -->
    <!-- GTM_PLACEHOLDER -->                                       <!-- line 10 -->
```

Insert the new block between lines 9 and 10 (after favicon, before GTM placeholder):
```html
    <meta http-equiv="Content-Security-Policy" content="..." />
    <link rel="icon" href="data:image/svg+xml,...">
    <!-- Open Graph -->
    <meta property="og:title" ... />
    ... (all new tags)
    <meta name="author" content="Eky Pratama" />
    <!-- GTM_PLACEHOLDER -->
```

- [ ] **Step 2: Verify build succeeds (CSP intact)**

```bash
npm run build
```
Expected: build succeeds without errors. No CSP hash mismatch warnings.

- [ ] **Step 3: Commit**

```bash
git add frontend/index.html
git commit -m "feat: add Open Graph + Twitter Card + SEO meta tags

Enables rich link previews on social platforms:
- WhatsApp, Telegram, Facebook, LinkedIn, Twitter/X, Slack, Discord
- og:image (1200x630) + secure_url for HTTPS enforcement
- twitter:card = summary_large_image with alt text
- canonical URL, robots index/follow, author meta

No CSP changes needed — all additions are <meta> and <link> tags."
```

---

### Task 5: Add JSON-LD Structured Data

**Files:**
- Modify: `frontend/index.html` (add `<script type="application/ld+json">` block in `<head>`)

**Interfaces:**
- Consumes: Task 4's `index.html` tag layout
- Produces: JSON-LD Person schema with entity disambiguation signals

- [ ] **Step 1: Insert JSON-LD script block in index.html `<head>`**

After the author meta tag (from Task 4), before GTM placeholder:

```html
    <script type="application/ld+json">
    {
      "@context": "https://schema.org",
      "@type": "Person",
      "name": "Eky Pratama",
      "alternateName": ["Eky", "Eky Putra Pratama"],
      "jobTitle": "Technical Lead & Senior Software Engineer",
      "description": "Technical Lead & Senior Software Engineer with 15+ years of experience in web platforms, cloud architecture, and AI-assisted development. Based in North Sydney, Australia.",
      "url": "https://ekyputrapratama.com",
      "mainEntityOfPage": {
        "@type": "ProfilePage",
        "@id": "https://ekyputrapratama.com/#profile"
      },
      "image": "https://ekyputrapratama.com/og-image.png",
      "sameAs": [
        "https://linkedin.com/in/ekyputrapratama",
        "https://github.com/epratama"
      ],
      "alumniOf": {
        "@type": "CollegeOrUniversity",
        "name": "University of Wollongong",
        "sameAs": "https://www.uow.edu.au"
      },
      "knowsAbout": [
        "React.js",
        "Python",
        "JavaScript",
        "PHP",
        "Cloud Architecture",
        "Multi-agent AI Orchestration",
        "AWS Serverless",
        "SaaS Platform Engineering",
        "Database Engineering",
        "OWASP Security Compliance",
        "ISO 27001"
      ],
      "worksFor": {
        "@type": "Organization",
        "name": "Swift Digital",
        "sameAs": "https://www.swiftdigital.com.au"
      },
      "homeLocation": {
        "@type": "Place",
        "name": "North Sydney, NSW, Australia"
      },
      "hasCredential": [
        {
          "@type": "EducationalOccupationalCredential",
          "name": "Common Cyber Security Threats and Mitigation Strategies",
          "recognizedBy": {
            "@type": "Organization",
            "name": "TAFE"
          }
        }
      ],
      "knowsLanguage": [
        {
          "@type": "Language",
          "name": "English"
        }
      ]
    }
    </script>
```

**Placement:** After the SEO meta tags block (Task 4), before GTM placeholder.

- [ ] **Step 2: Verify CSP allows JSON-LD script**

The `<script type="application/ld+json">` block is not executed as JavaScript. CSP `script-src` targets JavaScript execution only. Modern browsers (Chrome 90+, Firefox 90+, Safari 15+) correctly skip CSP enforcement for non-JavaScript script types.

Build verification:
```bash
npm run build
```
Expected: build succeeds with no CSP warnings.

- [ ] **Step 3: Validate JSON-LD syntax**

```bash
python3 -c "
import json
with open('frontend/index.html') as f:
    html = f.read()
start = html.find('\"@context\"')
end = html.find('</script>', start)
block = '{' + html[start:end].strip().rstrip(';')
json.loads(block)
print('JSON-LD: valid JSON')
"
```
Expected: `JSON-LD: valid JSON`

- [ ] **Step 4: Serve locally and verify no CSP console errors**

```bash
npx vite preview --port 4173 &
sleep 2
curl -s http://localhost:4173 | grep -o '"@context"' | head -1
kill %1 2>/dev/null
```
Expected: `"@context"` found in served HTML.

- [ ] **Step 5: Commit**

```bash
git add frontend/index.html
git commit -m "feat: add JSON-LD Person schema for AEO/GEO entity disambiguation

Schema.org Person with:
- mainEntityOfPage (ProfilePage) for entity-page alignment
- sameAs (LinkedIn + GitHub) for Knowledge Graph entity merge
- alumniOf (UoW) + worksFor (Swift Digital) for entity authority
- knowsAbout (11 skills) for AI Overview expertise extraction
- hasCredential (TAFE cert) for credential graph
- knowsLanguage (English) + homeLocation (Sydney) for geo consistency
- alternateName covers name variations across platforms

CSP safe: <script type='application/ld+json'> is not JavaScript execution."
```

---

### Task 6: Full Test Suite + Build Verification

**Files:**
- Test: `npx vitest run` (15 frontend tests)
- Test: `python3 -m pytest backend/test_lambda.py -q` (29 backend tests)
- Test: `bash tests/test_deploy.sh` (13 deploy tests)
- Test: `bash tests/test_template.sh` (17 template tests)
- Build: `npm run build` (Vite production build)

**Interfaces:**
- Consumes: all changes from Tasks 1-5
- Produces: green test suite (all 74 tests pass), successful production build

- [ ] **Step 1: Run frontend tests**

```bash
npx vitest run
```
Expected: 15 tests, all PASS.

**If any test fails:** STOP. Invoke `superpowers:systematic-debugging`. Do not proceed until all tests pass.

- [ ] **Step 2: Run backend tests**

```bash
python3 -m pytest backend/test_lambda.py -q
```
Expected: 29 tests, all PASS.

**If any test fails:** STOP. Invoke `superpowers:systematic-debugging`.

- [ ] **Step 3: Run deploy tests**

```bash
bash tests/test_deploy.sh
```
Expected: 13 tests, all PASS.

**If any test fails:** STOP. Invoke `superpowers:systematic-debugging`.

- [ ] **Step 4: Run template tests**

```bash
bash tests/test_template.sh
```
Expected: 17 tests, all PASS.

**If any test fails:** STOP. Invoke `superpowers:systematic-debugging`.

- [ ] **Step 5: Production build**

```bash
npm run build
```
Expected: build succeeds. Verify `dist/` contains:
- `index.html` with OG tags, Twitter Card meta, JSON-LD script, canonical link, robots meta, author meta
- `og-image.png` (1200×630)
- `robots.txt`
- `assets/` (JS/CSS bundles)

- [ ] **Step 6: Spot-check built index.html for all new content**

```bash
grep -c 'og:title' dist/index.html        # Expected: 1
grep -c 'og:image:secure_url' dist/index.html  # Expected: 1
grep -c 'twitter:card' dist/index.html    # Expected: 1
grep -c 'twitter:image:alt' dist/index.html   # Expected: 1
grep -c 'canonical' dist/index.html       # Expected: 1
grep -c 'application/ld+json' dist/index.html  # Expected: 1
grep -c 'ProfilePage' dist/index.html     # Expected: 1
grep -c 'sameAs' dist/index.html          # Expected: 1
grep -c 'React.js' dist/index.html        # Expected: 1 (in skills section)

# Verify all counts match
```

- [ ] **Step 7: Commit (if any test files were updated)**

```bash
git add -A
git diff --cached --stat
# Only commit if test files were modified to accommodate new content
git commit -m "test: update tests for SEO/social sharing changes"  # only if needed
```

---

### Task 7: CodeQL + Checkov Rescan

**Files:**
- Scan: entire repository (post-changes)

**Interfaces:**
- Compares: baseline (Task 0) vs rescan

- [ ] **Step 1: Run CodeQL security rescan**

```bash
skill: codeql-security-scan
```
Expected: 0 NEW findings vs baseline. Prior risk-accepted findings (CSRF, SSRF, CORS) may still show — that's expected.

**If any NEW finding appears:** STOP. Fix the finding, re-run tests (Task 6), then re-run this scan. Loop until clean.

- [ ] **Step 2: Run Checkov IaC rescan**

```bash
skill: checkov-iac-scan
```
Expected: 0 NEW findings vs baseline.

**If any NEW finding appears:** STOP. Fix, re-test, re-scan.

- [ ] **Step 3: Record rescan results**

Note: "Rescan complete. 0 new findings across CodeQL (JS + Python) and Checkov (CloudFormation)."

---

### Task 8: Code Review

**Files:**
- Review: full diff from `git diff main`

**Interfaces:**
- Produces: review feedback (if any) or approval

- [ ] **Step 1: Request code review**

```bash
skill: requesting-code-review
```

Reviewer checks:
- All OG tags present and correct
- All Twitter Card tags present and correct
- JSON-LD is valid Schema.org (no type errors, no missing required fields)
- All URLs are absolute `https://ekyputrapratama.com/...`
- CSP not broken (no `unsafe-inline` added, JSON-LD script doesn't trigger CSP)
- `robots.txt` content correct
- `resume.json` skills updated
- `og-image.png` dimensions correct (1200×630)

- [ ] **Step 2: If review feedback requires changes**

```
skill: receiving-code-review → assess → apply fixes → retest (Task 6) → CodeQL rescan (Task 7) → re-review (Task 8)
```

Loop until approval.

- [ ] **Step 3: Merge/commit review-approved changes**

---

### Task 9: Deploy

**Files:**
- Deploy: `./deploy.sh`

```bash
./deploy.sh
```

Expected: successful CloudFormation stack update, S3 sync, CloudFront invalidation.

- [ ] **Step 1: Run deploy.sh**

```bash
./deploy.sh
```

- [ ] **Step 2: Verify deployed files are accessible**

```bash
curl -sI https://ekyputrapratama.com/ | head -5
# Expected: HTTP/2 200

curl -sI https://ekyputrapratama.com/og-image.png | head -5
# Expected: HTTP/2 200, content-type: image/png

curl -sI https://ekyputrapratama.com/robots.txt
# Expected: HTTP/2 200, content includes "User-agent: *"

curl -s https://ekyputrapratama.com/ | grep 'og:title'
# Expected: <meta property="og:title" content="Eky Pratama — ..."

curl -s https://ekyputrapratama.com/ | grep 'application/ld+json'
# Expected: <script type="application/ld+json">

curl -s https://ekyputrapratama.com/ | grep 'React.js'
# Expected: React.js present in page content (skills section)
```

- [ ] **Step 3: Commit (if deploy.sh was modified)**

```bash
git add deploy.sh
git commit -m "chore: post-deploy verification"  # only if needed
```

---

### Task 10: Post-Deploy Verification

**Files:**
- Verification: external tools (no code changes)

- [ ] **Step 1: Validate JSON-LD with Google Rich Results Test**

Navigate to: `https://search.google.com/test/rich-results`
Enter URL: `https://ekyputrapratama.com`
Expected: "Person" rich result detected, 0 errors, 0 warnings.

- [ ] **Step 2: Validate OG tags with Facebook Sharing Debugger**

Navigate to: `https://developers.facebook.com/tools/debug/`
Enter URL: `https://ekyputrapratama.com`
Click "Debug"
Expected:
- og:title: "Eky Pratama — Technical Lead & Senior Software Engineer"
- og:image preview displays EP monogram
- og:image:width = 1200, og:image:height = 630
- 0 warnings, 0 errors

- [ ] **Step 3: Validate Twitter Card**

Navigate to: `https://cards-dev.twitter.com/validator`
Enter URL: `https://ekyputrapratama.com`
Click "Preview card"
Expected:
- Card type: summary_large_image
- Image preview displays EP monogram
- Title and description correct

- [ ] **Step 4: Validate LinkedIn Post Inspector**

Navigate to: `https://www.linkedin.com/post-inspector/`
Enter URL: `https://ekyputrapratama.com`
Click "Inspect"
Expected: image preview displays EP monogram.

- [ ] **Step 5: Manual WhatsApp test**

Send `https://ekyputrapratama.com` in a WhatsApp chat (to yourself or a trusted contact).
Expected: link preview shows EP monogram image, title, and description.

- [ ] **Step 6: Manual Telegram test**

Send `https://ekyputrapratama.com` in a Telegram chat.
Expected: instant view preview with EP monogram image.

- [ ] **Step 7: Verify robots.txt**

```bash
curl -s https://ekyputrapratama.com/robots.txt
```
Expected:
```
User-agent: *
Allow: /
Sitemap: https://ekyputrapratama.com/sitemap.xml
```

---

## Failure Protocol

At ANY step that fails (tests, build, scan, review):

1. **STOP.** Do not continue to next task.
2. Invoke `superpowers:systematic-debugging` to find root cause
3. Apply fix
4. Re-run the failed step (and only that step, unless fix touches other tasks)
5. If the fix changes code written in Tasks 1-5:
   - Re-run Task 6 (full test suite)
   - Re-run Task 7 (CodeQL rescan)
   - Re-run Task 8 (code review) if review already passed
6. Resume from where you stopped

---
