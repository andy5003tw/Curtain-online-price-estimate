import fs from 'node:fs';
import path from 'node:path';

const projectRoot = process.cwd();
const outDir = path.join(projectRoot, 'out');
const errors = [];

function fail(message) {
  errors.push(message);
}

function readFileSafe(filePath) {
  if (!fs.existsSync(filePath)) {
    fail(`Missing file: ${path.relative(projectRoot, filePath)}`);
    return '';
  }
  return fs.readFileSync(filePath, 'utf8');
}

function expectMatch(content, pattern, label, filePath) {
  if (!pattern.test(content)) {
    fail(`${label} not found in ${path.relative(projectRoot, filePath)}`);
  }
}

function checkPage(route, canonical) {
  const htmlPath = route === '/'
    ? path.join(outDir, 'index.html')
    : path.join(outDir, route.replace(/^\//, ''), 'index.html');
  const html = readFileSafe(htmlPath);
  if (!html) return;

  expectMatch(html, /<title>[\s\S]*?<\/title>/i, 'title tag', htmlPath);
  expectMatch(html, /<meta[^>]+name="description"[^>]+content=/i, 'meta description', htmlPath);
  expectMatch(html, /<meta[^>]+property="og:title"[^>]+content=/i, 'og:title', htmlPath);
  expectMatch(html, /<meta[^>]+name="twitter:card"[^>]+content=/i, 'twitter:card', htmlPath);

  const canonicalRegex = new RegExp(
    `<link[^>]+rel="canonical"[^>]+href="https://online\\.hong-sen\\.com${canonical.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}"`,
    'i'
  );
  expectMatch(html, canonicalRegex, `canonical ${canonical}`, htmlPath);

  const jsonLdMatches = [...html.matchAll(/<script[^>]+type="application\/ld\+json"[^>]*>([\s\S]*?)<\/script>/gi)];
  if (!jsonLdMatches.length) {
    fail(`JSON-LD missing in ${path.relative(projectRoot, htmlPath)}`);
    return;
  }

  for (const match of jsonLdMatches) {
    const payload = match[1]?.trim();
    if (!payload) continue;
    try {
      JSON.parse(payload);
    } catch {
      fail(`Invalid JSON-LD in ${path.relative(projectRoot, htmlPath)}`);
    }
  }
}

function checkSitemap() {
  const sitemapPath = path.join(outDir, 'sitemap.xml');
  const xml = readFileSafe(sitemapPath);
  if (!xml) return;

  const requiredUrls = [
    'https://online.hong-sen.com/',
    'https://online.hong-sen.com/products/custom-curtains/',
    'https://online.hong-sen.com/location/taipei/',
    'https://online.hong-sen.com/location/sanchong/',
    'https://online.hong-sen.com/curtain/blackout/',
    'https://online.hong-sen.com/blog/blackout-curtain-guide/',
  ];

  for (const url of requiredUrls) {
    if (!xml.includes(`<loc>${url}</loc>`)) {
      fail(`Sitemap missing URL: ${url}`);
    }
  }
}

function checkLegacyCanonical() {
  const legacyMap = {
    P001: '/products/custom-curtains/',
    P013: '/products/vertical-blinds/',
  };

  for (const [legacyId, canonicalPath] of Object.entries(legacyMap)) {
    const htmlPath = path.join(outDir, 'products', legacyId, 'index.html');
    const html = readFileSafe(htmlPath);
    if (!html) continue;

    const canonical = `https://online.hong-sen.com${canonicalPath}`;
    const regex = new RegExp(`<link[^>]+rel="canonical"[^>]+href="${canonical.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}"`, 'i');
    expectMatch(html, regex, `legacy canonical for ${legacyId}`, htmlPath);
  }
}

if (!fs.existsSync(outDir)) {
  fail('out directory not found. Run `npm.cmd run build` first.');
} else {
  checkPage('/', '/');
  checkPage('/products/', '/products/');
  checkPage('/products/custom-curtains/', '/products/custom-curtains/');
  checkPage('/location/taipei/', '/location/taipei/');
  checkPage('/location/sanchong/', '/location/sanchong/');
  checkPage('/blog/blackout-curtain-guide/', '/blog/blackout-curtain-guide/');
  checkSitemap();
  checkLegacyCanonical();
}

if (errors.length) {
  console.error('SEO preflight failed:');
  for (const error of errors) {
    console.error(`- ${error}`);
  }
  process.exit(1);
}

console.log('SEO preflight passed.');
