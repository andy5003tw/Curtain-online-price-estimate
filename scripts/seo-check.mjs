import fs from 'node:fs';
import path from 'node:path';

const SITE_URL = 'https://online.hong-sen.com';
const projectRoot = process.cwd();
const outDir = path.join(projectRoot, 'out');
const errors = [];

const legacyMap = {
  P001: '/products/custom-curtains/',
  P002: '/products/seamless-sheer-curtains/',
  P003: '/products/s-fold-curtains/',
  P004: '/products/roman-shades/',
  P005: '/products/roller-blinds/',
  P006: '/products/aluminum-blinds/',
  P007: '/products/wooden-blinds/',
  P008: '/products/bamboo-blinds/',
  P009: '/products/honeycomb-blinds/',
  P010: '/products/zebra-blinds/',
  P011: '/products/soft-sheer-blinds/',
  P012: '/products/hospital-curtains/',
  P013: '/products/vertical-blinds/',
};

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

function routeToOutHtml(route) {
  if (route === '/') {
    return path.join(outDir, 'index.html');
  }

  const clean = route.replace(/^\/+/, '').replace(/\/+$/, '');
  return path.join(outDir, clean, 'index.html');
}

function normalizeRoute(route) {
  if (route === '/') return '/';
  const withLeadingSlash = route.startsWith('/') ? route : `/${route}`;
  return withLeadingSlash.endsWith('/') ? withLeadingSlash : `${withLeadingSlash}/`;
}

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function assertMatch(content, pattern, label, filePath) {
  if (!pattern.test(content)) {
    fail(`${label} not found in ${path.relative(projectRoot, filePath)}`);
  }
}

function assertIncludes(content, snippet, label, filePath) {
  if (!content.includes(snippet)) {
    fail(`${label} not found in ${path.relative(projectRoot, filePath)}`);
  }
}

function checkHtmlPage(route) {
  const normalizedRoute = normalizeRoute(route);
  const htmlPath = routeToOutHtml(normalizedRoute);
  const html = readFileSafe(htmlPath);
  if (!html) return;

  assertMatch(html, /<title>[\s\S]*?<\/title>/i, 'title', htmlPath);
  assertMatch(html, /<meta[^>]+name="description"[^>]+content=/i, 'meta description', htmlPath);
  assertMatch(html, /<meta[^>]+property="og:title"[^>]+content=/i, 'og:title', htmlPath);
  assertMatch(html, /<meta[^>]+name="twitter:card"[^>]+content=/i, 'twitter:card', htmlPath);

  const canonical = `${SITE_URL}${normalizedRoute}`;
  const canonicalRegex = new RegExp(
    `<link[^>]+rel="canonical"[^>]+href="${escapeRegex(canonical)}"`,
    'i'
  );
  assertMatch(html, canonicalRegex, `canonical ${canonical}`, htmlPath);

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

function checkSitemapReachability() {
  const sitemapPath = path.join(outDir, 'sitemap.xml');
  const xml = readFileSafe(sitemapPath);
  if (!xml) return [];

  const urls = [...xml.matchAll(/<loc>([^<]+)<\/loc>/g)].map(match => match[1].trim());
  if (!urls.length) {
    fail('No <loc> entries found in out/sitemap.xml');
    return [];
  }

  const routes = [];
  for (const url of urls) {
    if (url.includes('/products/P')) {
      fail(`Legacy product URL should not exist in sitemap: ${url}`);
      continue;
    }

    let parsed;
    try {
      parsed = new URL(url);
    } catch {
      fail(`Invalid sitemap URL: ${url}`);
      continue;
    }

    if (`${parsed.protocol}//${parsed.host}` !== SITE_URL) {
      fail(`Unexpected sitemap domain: ${url}`);
      continue;
    }

    const route = normalizeRoute(parsed.pathname || '/');
    const htmlPath = routeToOutHtml(route);
    if (!fs.existsSync(htmlPath)) {
      fail(`Sitemap URL not reachable in out/: ${url} -> ${path.relative(projectRoot, htmlPath)}`);
      continue;
    }

    routes.push(route);
  }

  return routes;
}

function checkRobots() {
  const robotsPath = path.join(outDir, 'robots.txt');
  const robots = readFileSafe(robotsPath);
  if (!robots) return;

  const sitemapLine = `Sitemap: ${SITE_URL}/sitemap.xml`;
  if (!robots.includes(sitemapLine)) {
    fail(`robots.txt missing sitemap line: ${sitemapLine}`);
  }
}

function checkLegacyBehavior() {
  const htaccessPath = path.join(outDir, '.htaccess');
  const htaccess = readFileSafe(htaccessPath);
  if (!htaccess) return;

  for (const [legacyId, slugPath] of Object.entries(legacyMap)) {
    const legacyHtmlPath = path.join(outDir, 'products', legacyId, 'index.html');
    const legacyHtml = readFileSafe(legacyHtmlPath);
    if (!legacyHtml) continue;

    const canonical = `${SITE_URL}${slugPath}`;
    const canonicalRegex = new RegExp(
      `<link[^>]+rel="canonical"[^>]+href="${escapeRegex(canonical)}"`,
      'i'
    );
    assertMatch(legacyHtml, canonicalRegex, `legacy canonical for ${legacyId}`, legacyHtmlPath);

    const rewriteRegex = new RegExp(
      `RewriteRule\\s+\\^products\\/${legacyId}\\/\\?\\$\\s+${escapeRegex(slugPath)}\\s+\\[R=301,L\\]`,
      'i'
    );
    assertMatch(htaccess, rewriteRegex, `301 rule for ${legacyId}`, htaccessPath);
  }
}

function checkGeoFlow(geoRoutes) {
  for (const route of geoRoutes) {
    const areaId = route.replace(/^\/location\//, '').replace(/\/$/, '');
    if (!areaId || areaId === 'location') continue;

    const htmlPath = routeToOutHtml(route);
    const html = readFileSafe(htmlPath);
    if (!html) continue;

    assertMatch(
      html,
      /href="\/location\/"/i,
      `hub backlink for ${route}`,
      htmlPath
    );

    assertMatch(
      html,
      new RegExp(`\\/calculator\\/?\\?[^"<]*area=${escapeRegex(areaId)}`, 'i'),
      `area calculator link for ${route}`,
      htmlPath
    );
  }
}

function checkProductAreaFlow() {
  const sampleProductRoutes = ['/products/custom-curtains/', '/products/roller-blinds/'];
  for (const route of sampleProductRoutes) {
    const htmlPath = routeToOutHtml(route);
    const html = readFileSafe(htmlPath);
    if (!html) continue;

    assertIncludes(html, '可服務區域快速入口', 'service area quick entry text', htmlPath);
    assertIncludes(html, '直接估價此產品', 'direct product estimate text', htmlPath);
    assertIncludes(html, '前往整體估價頁', 'full calculator text', htmlPath);

    assertMatch(
      html,
      /\/calculator\/?\?[^"<]*product=P\d{3}[^"<]*area=[a-z0-9-]+/i,
      `product+area calculator link for ${route}`,
      htmlPath
    );
  }
}

if (!fs.existsSync(outDir)) {
  fail('out directory not found. Run `npm.cmd run build` first.');
} else {
  const sitemapRoutes = checkSitemapReachability();
  if (!sitemapRoutes.includes('/location/')) {
    fail('sitemap missing /location/ hub route');
  }
  checkRobots();
  checkLegacyBehavior();

  const requiredRoutes = [
    '/',
    '/location/',
    '/products/',
    '/products/custom-curtains/',
    '/location/taipei/',
    '/location/sanchong/',
    '/location/xinyi/',
    '/location/banqiao/',
    '/blog/blackout-curtain-guide/',
  ];

  const geoRoutes = sitemapRoutes.filter(
    route => route.startsWith('/location/') && route !== '/location/'
  );
  const productRoutes = sitemapRoutes.filter(
    route => route.startsWith('/products/') && !/^\/products\/P\d{3}\/$/i.test(route)
  );
  const routesToValidate = new Set([...requiredRoutes, ...geoRoutes, ...productRoutes]);
  for (const route of routesToValidate) {
    checkHtmlPage(route);
  }

  checkGeoFlow(geoRoutes);
  checkProductAreaFlow();
}

if (errors.length) {
  console.error('SEO check failed:');
  for (const error of errors) {
    console.error(`- ${error}`);
  }
  process.exit(1);
}

console.log('SEO check passed.');
