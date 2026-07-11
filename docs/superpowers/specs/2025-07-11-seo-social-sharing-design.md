# SEO, Social Sharing & AI Optimization Design

**Date:** 2025-07-11
**Status:** Design (v1.1 — consortium-audited)

## Goal

Enable social media link previews (Open Graph / Twitter Card) and improve search engine + AI Overview (AEO/GEO) visibility for `ekyputrapratama.com`.

## Problem

- Social sharing (WhatsApp, Telegram, Facebook, LinkedIn, Twitter/X) shows no preview image or rich card because `index.html` has zero `og:` or `twitter:` meta tags
- The favicon is an inline SVG data URI — social platforms cannot use it as a share image
- Multiple people named "Eky Pratama" appear in Google search; no structured data or entity disambiguation signals exist to distinguish this profile
- `resume.json` skills list is missing React.js and Python despite both being used in the codebase

## Non-Goals

- Blog, CMS, or dynamic content pages
- Ongoing content strategy for SEO
- Sitemap.xml (single-page site, unnecessary until Search Console submission)
- Paid search / ads

## Design

### 1. Social Share Image

**File:** `frontend/public/og-image.png`
**Specs:** 1200x630px PNG, dark background (`#18181B`), centered "EP" monogram in blue (`#2563EB`), Archivo font, weight 800, font-size proportional to height. Same visual as favicon, scaled for social card dimensions.

**Generation:** Via Node.js `canvas` package (`npx`) or imagemagick `convert` fallback.

### 2. Open Graph + Twitter Card Tags

Added to `index.html` `<head>`:

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
```

**CSP impact:** None. `img-src 'self'` covers the share image. OG/Twitter tags are `<meta>`, no script/style directive concern.

**Platform coverage:** WhatsApp, Telegram, Facebook, LinkedIn, Twitter/X, Slack, Discord, iMessage — all read `og:` tags. Twitter explicit tags ensure `summary_large_image` card over default `summary`.

### 3. SEO Meta Tags + Crawler Directives

Added to `index.html` `<head>`:

```html
<link rel="canonical" href="https://ekyputrapratama.com" />
<meta name="robots" content="index, follow" />
<meta name="author" content="Eky Pratama" />
```

**New file:** `frontend/public/robots.txt`

```
User-agent: *
Allow: /
Sitemap: https://ekyputrapratama.com/sitemap.xml
```

Vite auto-copies `public/` → `dist/` root.

**Rationale:**
- `canonical` — prevents duplicate content penalty from `www` vs non-www or mirrored copies
- `robots` meta — explicit indexing signal (AI crawlers increasingly respect this)
- `author` — additional entity name match for disambiguation
- `robots.txt` — first file crawlers request; absence delays indexing on Bing/Yandex

### 4. JSON-LD Structured Data (Person Schema)

Added to `index.html` `<head>`:

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

**CSP impact:** None. `script-src 'self'` covers inline JSON-LD `<script>` blocks.

**AEO/GEO strategy per field:**

| Field | Purpose for AI disambiguation |
|---|---|
| `mainEntityOfPage` | Declares the page IS about this entity via `ProfilePage`. Google uses this to validate entity-page alignment for Rich Results and AI Overviews |
| `sameAs` | Merges Google Knowledge Graph entity across LinkedIn + GitHub. Single most important field — without it, AI models treat each platform's "Eky Pratama" as separate people |
| `alternateName` | Catches variations ("Eky Putra Pratama" on LinkedIn vs "Eky Pratama" on GitHub) |
| `alumniOf` | Links to known educational entity (UoW). .edu authoritative backlink for Knowledge Graph |
| `worksFor` | Links to known organization (Swift Digital). Weighted heavily by AI for entity verification |
| `knowsAbout` | Maps expertise domains. Google AI Overviews uses this for "who knows about X" retrieval-augmented generation queries |
| `homeLocation` | Geographic disambiguation — separates from other "Eky Pratama" results in Indonesia/Malaysia |
| `hasCredential` | Maps to Google's credential graph. Verified qualifications boost entity authority |
| `knowsLanguage` | Linguistic + geographic signal. Combined with `homeLocation` creates consistent entity profile |

### 5. Skills Data Fix

**File:** `frontend/src/data/resume.json`

Current `skills[6]` ("Languages & Frameworks"):
```json
"items": ["PHP", "JavaScript", "Node.js", "jQuery", "CSS/Sass", "Bootstrap", "SurveyJS"]
```

Updated:
```json
"items": ["PHP", "JavaScript", "Node.js", "React.js", "Python", "jQuery", "CSS/Sass", "Bootstrap", "SurveyJS"]
```

**Rationale:** React.js is the site's own framework. Python is the Lambda backend language (29 pytest tests). Both are marketable skills absent from the display.

## Files Changed

| File | Action | Content |
|---|---|---|
| `frontend/index.html` | Edit | OG + Twitter Card + canonical + robots + author + JSON-LD |
| `frontend/public/og-image.png` | New | 1200x630 EP monogram PNG |
| `frontend/public/robots.txt` | New | Crawler allow rules |
| `frontend/src/data/resume.json` | Edit | Add React.js + Python to Languages & Frameworks |

## No Changes Needed

- **CSP** — `img-src 'self'` covers share image; `script-src 'self'` covers JSON-LD; all others are `<meta>` tags
- **deploy.sh** — no change; Vite build copies `public/` to `dist/` automatically
- **CloudFormation** — no change; S3 upload step in deploy.sh picks up new files from `dist/`

## Verification

- [ ] `og-image.png` exists at `https://ekyputrapratama.com/og-image.png` (200 OK)
- [ ] `robots.txt` exists at `https://ekyputrapratama.com/robots.txt` (200 OK)
- [ ] Facebook Sharing Debugger shows image preview (post-deploy)
- [ ] LinkedIn Post Inspector shows image preview (post-deploy)
- [ ] Google Rich Results Test validates JSON-LD (post-deploy: `https://search.google.com/test/rich-results`)
- [ ] Twitter Card Validator shows `summary_large_image` (post-deploy)
- [ ] `npx vitest run` — all 15 frontend tests still pass
- [ ] `npm run build` — build succeeds (CSP inline hash valid, JSON-LD doesn't break CSP)

## Post-Deploy Manual Steps

1. Submit `https://ekyputrapratama.com` to [Google Search Console](https://search.google.com/search-console)
2. Submit to [Bing Webmaster Tools](https://www.bing.com/webmasters)
3. Request re-indexing of key platforms:
   - Facebook: [Sharing Debugger](https://developers.facebook.com/tools/debug/)
   - LinkedIn: [Post Inspector](https://www.linkedin.com/post-inspector/)
   - Twitter/X: [Card Validator](https://cards-dev.twitter.com/validator)

## Audit Consortium (MoA)

v1.1 amendments applied after 4-agent audit:

| Agent | Round 1 | Round 2 | Key Findings |
|---|---|---|---|
| SEO Technical | PASS WITH NOTES | PASS | Missing `og:image:secure_url`, `twitter:image:alt`, `mainEntityOfPage`, `hasCredential`, `knowsLanguage` |
| Security & Privacy | PASS WITH NOTES | PASS | JSON-LD CSP verification, no new PII or attack surface |
| Social/OG Compliance | PASS WITH NOTES (1 HIGH) | PASS | `og:image:secure_url` for Facebook HTTPS, `twitter:image:alt` for accessibility, 1200x630 compromise dimension accepted |
| AEO/GEO Strategy | PASS WITH NOTES | PASS | `mainEntityOfPage` (ProfilePage) critical for entity-page alignment; `hasCredential` + `knowsLanguage` added for credential graph and geo consistency |

## Changelog

| Version | Date | Changes |
|---|---|---|
| v1.0 | 2025-07-11 | Initial design: OG tags, Twitter Card, JSON-LD Person schema, SEO meta tags, robots.txt, resume.json skills fix |
| v1.1 | 2025-07-11 | Consortium audit: added `og:image:secure_url`, `twitter:image:alt`, `mainEntityOfPage` (ProfilePage), `hasCredential` (TAFE cert), `knowsLanguage` (English) |
