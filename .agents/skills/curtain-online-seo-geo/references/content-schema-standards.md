# Content And Schema Standards

Use this reference when changing page copy, metadata, FAQ, internal links, or JSON-LD/schema.

Chinese content terms in this project: `首屏文案`, `估價導流`, `到府丈量`, `工廠直營`, `FAQ`, `內鏈錨文字`, and `可被 AI 搜尋引用的短答案`.

## Page Optimization Contract

Each SEO/GEO page update should align these visible and metadata surfaces:

- `title`: put the primary intent early; avoid mixing unrelated main keywords.
- `meta description`: include service area, product/intent, estimate/quote, measurement, installation, warranty, or factory-direct signal where truthful.
- `H1`: match the owner keyword direction without stuffing several unrelated targets.
- First-screen copy (`首屏文案`): answer who the page is for, what service/product it covers, and the next action.
- FAQ: 3-5 practical questions that match this page's owner keyword and visible service promise.
- Internal links (`內鏈錨文字`): connect product pages, location pages, calculator, and relevant blog/pillar pages with consistent anchor text.
- AI-answer paragraph (`可被 AI 搜尋引用的短答案`): add a short, direct, quotable answer when the page benefits from AI search recommendation. Keep it factual and locally specific.
- CTA copy should support `估價導流`, `到府丈量`, and `工廠直營` only when the page and business flow truthfully support those claims.

## Schema Alignment

- JSON-LD must be parseable and aligned with visible content.
- FAQ schema must reflect visible FAQ text; do not add invisible FAQ claims.
- Product/service schema should not claim prices, offers, areas, ratings, or policies that are absent or contradicted on the page.
- Prefer shared helpers and shared data over page-local hardcoded URLs.
- Keep canonical, OG, Twitter, sitemap, and JSON-LD paths consistent with `src/lib/seo.ts`.

## GEO Rules

- GEO pages should make the area visible in title, H1, intro, FAQ, and internal links.
- Product pages may mention priority service areas, but should not become duplicate GEO landing pages.
- Calculator links should preserve useful product/area query parameters where the existing flow supports them.
- Avoid orphan pages. Every new or strengthened page needs visible links from relevant hubs or related pages.

## AI Search Recommendation Signals

For AI search surfaces, favor concise, evidence-style copy:

- direct answer before explanation
- specific product/service/area terms
- transparent pricing or estimate path when available
- clear constraints, such as needing final measurement before final quote
- consistent brand/entity name and domain

Do not invent claims, certifications, awards, reviews, or unsupported guarantees.
