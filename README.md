# Curtain Online Price Estimate

Next.js static-export site for curtain product pages, SEO/GEO content, and schema validation.

## Prerequisites

- Node.js 20+

## Local Development

1. Install dependencies:
   `npm.cmd install`
2. Start dev server:
   `npm.cmd run dev`

## Build and Export

1. Build static export:
   `npm.cmd run build`
2. Exported files are generated in:
   `out/`

## SEO Checks

- Quick SEO checks:
  `npm.cmd run seo:check`
- Preflight checks on exported output:
  `npm.cmd run seo:preflight`

## Deployment

- Upload the contents inside `out/` to the web root.
- Do not upload the `out` folder as a nested directory.

## Weekly SOP

- Main folder:
  `Weekly SOP/`
- Latest report snapshots:
  `Weekly SOP/latest/`
- Historical report packages:
  `Weekly SOP/reports/`
