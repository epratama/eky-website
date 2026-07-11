# robots.txt Fix Design

## Problem

1. **Dangling sitemap reference:** `robots.txt` references `https://ekyputrapratama.com/sitemap.xml` but no `sitemap.xml` exists in the project, causing a crawl error.
2. **AI crawler opt-out:** Google-Extended and other AI crawlers interpret the absence of an explicit `Allow` directive as opt-out. Verified when Gemini's automated browser returned `URL_FETCH_STATUS_GOOGLE_EXTENDED_OPT_OUT` and refused to render the page.

## Scope

Single file change: `frontend/public/robots.txt`. No new files, no infrastructure changes, no sitemap.xml (YAGNI for a single-page React SPA portfolio).

## Design

Replace file content with explicit AI crawler allowances plus a wildcard catch-all for everything else:

```
User-agent: Google-Extended
Allow: /

User-agent: GPTBot
Allow: /

User-agent: ClaudeBot
Allow: /

User-agent: CCBot
Allow: /

User-agent: anthropic-ai
Allow: /

User-agent: *
Allow: /
```

### Rationale

- **Google-Extended, GPTBot, ClaudeBot, CCBot, anthropic-ai** — each gets an explicit `Allow: /` to resolve AI crawler opt-out errors. These are the known AI crawler tokens as of 2026-07-11.
- **`User-agent: *`** — catch-all for search engines (Googlebot, Bingbot, DuckDuckBot, etc.) and any future crawlers not explicitly listed.
- **No `Sitemap:` directive** — removed because no `sitemap.xml` exists in the project and a single-page portfolio does not benefit from one.

## Verification

1. `robots.txt` returns 200 OK at `https://ekyputrapratama.com/robots.txt`
2. File content matches the spec above byte-for-byte
3. Google-Extended fetch no longer returns `URL_FETCH_STATUS_GOOGLE_EXTENDED_OPT_OUT`
4. Vite build copies `robots.txt` to `dist/robots.txt` (existing behavior, unchanged)