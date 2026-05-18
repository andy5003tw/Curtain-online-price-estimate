# Repo Map

Use this reference when you need to understand where SEO/GEO/schema truth lives in `Curtain-online-price-estimate`.

## Live Control Files

- `plan.md`: compact live control board for current SEO/GEO/schema state, unfinished items, next execution order, deploy boundaries, and validation evidence.
- `Phase2.md` through `Phase7.md`: completed implementation history and validation detail. Read these only when older evidence is needed.
- `Weekly SOP/12-keyword-pool-v*.md`: keyword-owner maps and 6-page ranking batch order.
- `Weekly SOP/history/7d/current_*_baseline.normalized.csv`: current 7-day GSC query/page baseline.
- `Weekly SOP/history/28d/current_*_baseline.normalized.csv`: current 28-day GSC query/page baseline.

## Source Ownership

- `src/lib/seo.ts`: shared SEO helper center. Use it for `SITE_URL`, `CATALOG_URL`, `absoluteUrl()`, `productPath()`, `buildCanonicalUrl()`, `buildCalculatorUrl()`, and OG/Twitter helpers.
- `src/data/products.ts`: product source of truth, including ids, semantic slugs, primary/secondary keywords, pricing, product SEO metadata, reviews, FAQs, and related blog data.
- `src/data/locationPages.ts`: GEO page source of truth, including area ids, titles, keywords, service highlights, advantages, FAQs, and related areas.
- `src/data/knowledgePosts.ts`: blog/knowledge post content and metadata.
- `src/data/pillarPages.ts`: `/curtain/[type]/` pillar-page data.
- `src/app/products/[slug]/page.tsx`: product page rendering, metadata, JSON-LD, visible content, FAQ, and internal link behavior.
- `src/app/location/[area]/page.tsx`: service-area page rendering, metadata, visible local content, FAQ, and internal link behavior.
- `src/app/sitemap.ts` and `src/app/robots.ts`: generated sitemap and robots output.
- `scripts/seo-check.mjs`: full local static-export SEO check. Prefer this over ad hoc manual checks.
- `scripts/seo-preflight.mjs`: smaller representative preflight check.

## Generated And Deploy Artifacts

- `out/`: generated static export. Build output only; never edit it directly.
- Static-site deploy uploads the contents inside `out/` to the site root.
- Do not upload project-control files as static-site content: `plan.md`, `Phase*.md`, `Weekly SOP`, `.agents`, local scripts, or raw baselines.

## Boundaries

- This skill is for on-site SEO/GEO/schema, ranking batches, and static-export validation.
- If a task touches admin pricing, PHP API files, credentials, or server-side business rules, inspect `README.md`, `.gitignore`, `private/`, `api/`, and `admin/` separately before applying any deploy assumptions from this SEO skill.
- Chinese business terms in this project: `關鍵字詞池` = keyword pool, `主攻詞` = target keyword, `綁定主頁` = owner page, `詞頁對齊` = aligning one keyword intent to one page, `排名前10` = Top-10 ranking goal, `上線驗收` = live verification.
- Keep technical identifiers in English or source form: `canonical`, `JSON-LD`, `sitemap`, `robots.txt`, `out/`, `npm.cmd`, helper names, file paths, and URL paths.
