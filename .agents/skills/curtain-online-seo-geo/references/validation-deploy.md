# Validation And Deploy

Use this reference before finishing or deploying SEO/GEO/schema work.

## Local Validation

Run the fixed validation loop after source changes:

```powershell
npm.cmd run build
npm.cmd run seo:check
```

Use `npm.cmd` on Windows because PowerShell may block or redirect `npm.ps1`.

`npm.cmd run build` regenerates `out/`. `npm.cmd run seo:check` verifies static-export HTML, sitemap reachability, robots sitemap line, canonical URLs, JSON-LD parseability, GEO flow links, product calculator links, and legacy `Pxxx -> slug` behavior.

## Static Deploy Boundary

For the static Next.js site:

- Upload the contents inside `out/` to the web root for `https://online.hong-sen.com/`.
- Do not upload the `out/` folder as a nested folder.
- Do not upload `plan.md`, `Phase*.md`, `Weekly SOP`, `.agents`, `scripts`, raw CSV baselines, local reports, or source files as static site content.

## Live Verification

When deployment is in scope, verify live behavior, not only FTP timestamps:

- target pages return HTTP 200
- canonical points to the intended semantic URL
- JSON-LD exists and parses
- `https://online.hong-sen.com/sitemap.xml` includes target semantic URLs
- representative legacy product URLs redirect to the slug URL
- key internal links and calculator links are present on the live HTML

## Reporting Back

Summarize:

- pages or data sources changed
- build and SEO check result
- deployment boundary used
- live checks performed
- anything not verified and why

Keep deployment notes concrete and avoid broad SEO theory in final status updates.
