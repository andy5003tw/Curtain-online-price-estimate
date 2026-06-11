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

## FTP Upload SOP

Use the project deploy script for every FTP upload. Do not paste ad hoc `FtpWebRequest` upload blocks unless the script is broken and the user approves a fallback.

Default flow:

```powershell
npm.cmd run build
npm.cmd run seo:check
npm.cmd run seo:preflight
npm.cmd run deploy:ftp:dry
npm.cmd run deploy:ftp
```

`deploy:ftp` runs `scripts/deploy-ftp.ps1` in `quick` mode. It selects deployment-critical files only: generated HTML/TXT, sitemap, robots, `.htaccess`, and `_next/static`. It checks remote file sizes, skips same-size files, uploads sequentially with per-file progress, and retries transient failures.

Use `quick` mode for normal SEO/GEO batches, schema changes, title/meta updates, FAQ changes, internal link changes, sitemap updates, and route HTML changes.

Use page-only upload for small corrections after a successful build/export:

```powershell
pwsh -NoLogo -ExecutionPolicy Bypass -File scripts/deploy-ftp.ps1 -Mode paths -Path /location/zhongzheng/,/curtain/blackout/
```

Use full upload only when static assets outside the quick set changed or the remote site is known to be missing assets:

```powershell
npm.cmd run deploy:ftp:all
```

Before a real FTP upload, ensure credentials are supplied by environment variables instead of editing them into repo files:

```powershell
$env:FTP_HOST='ftp.hong-sen.com'
$env:FTP_REMOTE_DIR='online.hong-sen.com'
$env:FTP_USER='...'
$env:FTP_PASS='...'
```

Do not commit or write FTP passwords into `package.json`, `.agents`, `scripts`, docs, source, or generated public files.

If an upload seems stuck, do not immediately rerun a full upload. Check:

- whether `deploy:ftp` is printing per-file progress
- whether the command is in `quick`, `paths`, or `all` mode
- whether live target pages already changed
- whether only a focused page-only upload is needed
- whether missing `_next/static` files require a quick upload

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
