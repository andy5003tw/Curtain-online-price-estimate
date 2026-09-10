import fs from 'node:fs';
import path from 'node:path';

const SITE_URL = 'https://online.hong-sen.com';
const projectRoot = process.cwd();
const outDir = path.join(projectRoot, 'out');
const errors = [];
const auditedPages = new Map();

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

function decodeHtml(value) {
  return value
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;|&apos;/gi, "'")
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&#(\d+);/g, (_, code) => String.fromCodePoint(Number(code)));
}

function normalizeText(value) {
  return decodeHtml(value.replace(/<[^>]*>/g, ' ')).replace(/\s+/g, ' ').trim();
}

function getTagTexts(html, tagName) {
  const pattern = new RegExp(`<${tagName}\\b[^>]*>([\\s\\S]*?)<\\/${tagName}>`, 'gi');
  return [...html.matchAll(pattern)].map(match => normalizeText(match[1] || ''));
}

function getVisibleText(html) {
  return normalizeText(
    html
      .replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, ' ')
      .replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi, ' ')
  );
}

function collectSchemaNodes(value, nodes = []) {
  if (Array.isArray(value)) {
    for (const item of value) collectSchemaNodes(item, nodes);
    return nodes;
  }
  if (!value || typeof value !== 'object') return nodes;
  if (value['@type']) nodes.push(value);
  if (Array.isArray(value['@graph'])) collectSchemaNodes(value['@graph'], nodes);
  return nodes;
}

function schemaHasType(nodes, type) {
  return nodes.some(node => {
    const nodeType = node['@type'];
    return Array.isArray(nodeType) ? nodeType.includes(type) : nodeType === type;
  });
}

function extractJsonLd(html, htmlPath) {
  const payloads = [];
  const matches = [...html.matchAll(/<script[^>]+type="application\/ld\+json"[^>]*>([\s\S]*?)<\/script>/gi)];
  if (!matches.length) {
    fail(`JSON-LD missing in ${path.relative(projectRoot, htmlPath)}`);
    return payloads;
  }
  for (const match of matches) {
    const payload = match[1]?.trim();
    if (!payload) continue;
    try {
      payloads.push(JSON.parse(payload));
    } catch {
      fail(`Invalid JSON-LD in ${path.relative(projectRoot, htmlPath)}`);
    }
  }
  return payloads;
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

  const titles = getTagTexts(html, 'title');
  const h1s = getTagTexts(html, 'h1');
  if (titles.length !== 1) fail(`Expected exactly one title in ${path.relative(projectRoot, htmlPath)}; found ${titles.length}`);
  if (h1s.length !== 1) fail(`Expected exactly one H1 in ${path.relative(projectRoot, htmlPath)}; found ${h1s.length}`);
  const visibleText = getVisibleText(html);
  if (/找不到頁面|page not found|404 not found/i.test(`${titles[0] || ''} ${h1s[0] || ''}`)) {
    fail(`Soft-404 signal found on sitemap route ${normalizedRoute}`);
  }
  if (visibleText.length < 200) fail(`Thin/soft-404 candidate on ${normalizedRoute}: only ${visibleText.length} visible characters`);

  const schemaPayloads = extractJsonLd(html, htmlPath);
  auditedPages.set(normalizedRoute, {
    route: normalizedRoute,
    htmlPath,
    html,
    title: titles[0] || '',
    h1: h1s[0] || '',
    visibleText,
    schemaPayloads,
    schemaNodes: schemaPayloads.flatMap(payload => collectSchemaNodes(payload)),
  });
}

function checkUniqueTitlesAndH1s() {
  for (const field of ['title', 'h1']) {
    const owners = new Map();
    for (const page of auditedPages.values()) {
      const key = page[field].toLocaleLowerCase('zh-TW');
      if (!key) continue;
      const routes = owners.get(key) || [];
      routes.push(page.route);
      owners.set(key, routes);
    }
    for (const [value, routes] of owners) {
      if (routes.length > 1) fail(`Duplicate ${field} across ${routes.join(', ')}: ${value}`);
    }
  }
}

function checkFaqParity(page) {
  const faqNodes = page.schemaNodes.filter(node => {
    const type = node['@type'];
    return Array.isArray(type) ? type.includes('FAQPage') : type === 'FAQPage';
  });
  for (const faqNode of faqNodes) {
    for (const entity of faqNode.mainEntity || []) {
      const question = normalizeText(String(entity?.name || ''));
      const answer = normalizeText(String(entity?.acceptedAnswer?.text || ''));
      if (!question || !page.visibleText.includes(question)) fail(`FAQ question is not visible on ${page.route}: ${question || '(empty)'}`);
      if (!answer || !page.visibleText.includes(answer)) fail(`FAQ answer is not visible on ${page.route}: ${answer || '(empty)'}`);
    }
  }
}

function checkSchemaContracts() {
  const ownerRoutes = new Set(Object.values(legacyMap));
  for (const page of auditedPages.values()) {
    checkFaqParity(page);
    if (page.route === '/') {
      if (!schemaHasType(page.schemaNodes, 'WebSite')) fail('Homepage schema missing WebSite');
      if (!schemaHasType(page.schemaNodes, 'LocalBusiness') && !schemaHasType(page.schemaNodes, 'Organization')) fail('Homepage schema missing Organization/LocalBusiness');
      if (!page.html.includes('data-ai-answer="true"')) fail('Homepage missing data-ai-answer contract');
    }
    if (ownerRoutes.has(page.route)) {
      if (!schemaHasType(page.schemaNodes, 'Product')) fail(`Product schema missing on ${page.route}`);
      if (!schemaHasType(page.schemaNodes, 'BreadcrumbList')) fail(`Product BreadcrumbList missing on ${page.route}`);
      if (!schemaHasType(page.schemaNodes, 'FAQPage')) fail(`Product FAQPage missing on ${page.route}`);
      if (!page.html.includes('data-ai-answer="true"')) fail(`Product AI answer missing on ${page.route}`);
      const product = page.schemaNodes.find(node => node['@type'] === 'Product');
      const offer = product?.offers;
      if (!offer || offer['@type'] !== 'AggregateOffer') {
        fail(`Product AggregateOffer missing on ${page.route}`);
      } else {
        const lowPrice = Number(offer.lowPrice);
        const highPrice = Number(offer.highPrice);
        const offerCount = Number(offer.offerCount);
        if (offer.priceCurrency !== 'TWD') fail(`Product AggregateOffer currency must be TWD on ${page.route}`);
        if (!Number.isFinite(lowPrice) || lowPrice < 0) fail(`Product AggregateOffer lowPrice is invalid on ${page.route}`);
        if (!Number.isFinite(highPrice) || highPrice < lowPrice) fail(`Product AggregateOffer highPrice is invalid on ${page.route}`);
        if (!Number.isInteger(offerCount) || offerCount < 1) fail(`Product AggregateOffer offerCount is invalid on ${page.route}`);
        if (offer.url !== `${SITE_URL}${page.route}`) fail(`Product AggregateOffer URL must match canonical on ${page.route}`);
      }
      const faq = page.schemaNodes.find(node => node['@type'] === 'FAQPage');
      const count = Array.isArray(faq?.mainEntity) ? faq.mainEntity.length : 0;
      if (count < 3 || count > 5) fail(`Product FAQ count must be 3-5 on ${page.route}; found ${count}`);
    }
    if (page.route.startsWith('/location/') && page.route !== '/location/') {
      if (!schemaHasType(page.schemaNodes, 'Service')) fail(`Location Service schema missing on ${page.route}`);
      if (!schemaHasType(page.schemaNodes, 'BreadcrumbList')) fail(`Location BreadcrumbList missing on ${page.route}`);
      if (!schemaHasType(page.schemaNodes, 'FAQPage')) fail(`Location FAQPage missing on ${page.route}`);
      const localBusinessCount = page.schemaNodes.filter(node => node['@type'] === 'LocalBusiness').length;
      if (localBusinessCount > 1) fail(`Location route creates a duplicate LocalBusiness entity on ${page.route}`);
      const serviceNode = page.schemaNodes.find(node => node['@type'] === 'Service');
      if (serviceNode?.provider?.['@id'] !== `${SITE_URL}/#localBusiness`) fail(`Location Service provider must reference the shared company entity on ${page.route}`);
      const expectedAreaType = ['/location/taipei/', '/location/new-taipei/'].includes(page.route) ? 'City' : 'AdministrativeArea';
      if (serviceNode?.areaServed?.['@type'] !== expectedAreaType) {
        fail(`Location Service areaServed must be ${expectedAreaType} on ${page.route}`);
      }
    }
    if (schemaHasType(page.schemaNodes, 'Review') || schemaHasType(page.schemaNodes, 'AggregateRating')) {
      fail(`Unbound Review/AggregateRating schema is not allowed on ${page.route}`);
    }
    const prohibitedClaims = [
      /1,284\+.*客戶評價/,
      /5,000\+.*安裝案例/,
      /服務萬戶/,
      /消防局認可/,
      /均已通過.*認證/,
      /通過醫院採購評審/,
      /感染風險降低/,
    ];
    for (const pattern of prohibitedClaims) {
      if (pattern.test(page.visibleText)) fail(`Unsupported evidence claim on ${page.route}: ${pattern}`);
    }
  }
}

function checkLocationHubContract(geoRoutes) {
  const cityOverviewRoutes = new Set(['/location/taipei/', '/location/new-taipei/']);
  const administrativeRoutes = geoRoutes.filter(route => !cityOverviewRoutes.has(route));
  if (administrativeRoutes.length !== 29) fail(`Expected 29 administrative location routes; found ${administrativeRoutes.length}`);
  if (geoRoutes.length !== 31) fail(`Expected 31 indexable location routes; found ${geoRoutes.length}`);

  const hub = auditedPages.get('/location/');
  if (!hub) return;
  const itemList = hub.schemaNodes.find(node => node['@type'] === 'ItemList');
  if (!itemList) {
    fail('Location hub schema missing ItemList');
    return;
  }
  if (Number(itemList.numberOfItems) !== geoRoutes.length) {
    fail(`Location hub ItemList count must be ${geoRoutes.length}; found ${itemList.numberOfItems}`);
  }

  const itemRoutes = (itemList.itemListElement || []).map(item => {
    const url = String(item?.url || '');
    if (!url) {
      fail('Location hub ItemList contains an item without a URL');
      return '';
    }
    let parsed;
    try {
      parsed = new URL(url);
    } catch {
      fail(`Location hub ItemList URL is invalid: ${url}`);
      return '';
    }
    if (parsed.hash) fail(`Location hub ItemList must not contain fragment URL: ${url}`);
    return normalizeRoute(parsed.pathname);
  }).filter(Boolean);

  const expectedRoutes = new Set(geoRoutes);
  if (itemRoutes.length !== expectedRoutes.size || new Set(itemRoutes).size !== itemRoutes.length) {
    fail('Location hub ItemList must contain each indexable location route exactly once');
  }
  for (const route of expectedRoutes) {
    if (!itemRoutes.includes(route)) fail(`Location hub ItemList missing sitemap location route: ${route}`);
  }
}

function checkInternalLinksAndOrphans(sitemapRoutes) {
  const sitemapSet = new Set(sitemapRoutes);
  const inbound = new Map(sitemapRoutes.map(route => [route, new Set()]));
  for (const page of auditedPages.values()) {
    for (const match of page.html.matchAll(/<a\b[^>]*href="([^"]+)"/gi)) {
      const href = decodeHtml(match[1] || '').trim();
      if (!href || href.startsWith('#') || /^(mailto:|tel:|javascript:)/i.test(href)) continue;
      let parsed;
      try { parsed = new URL(href, `${SITE_URL}${page.route}`); } catch { fail(`Invalid internal link on ${page.route}: ${href}`); continue; }
      if (`${parsed.protocol}//${parsed.host}` !== SITE_URL) continue;
      if (/^\/(?:_next|api)\//.test(parsed.pathname) || /\.[a-z0-9]{2,6}$/i.test(parsed.pathname)) continue;
      const target = normalizeRoute(parsed.pathname || '/');
      if (/^\/products\/P\d{3}\/$/i.test(target)) fail(`Legacy product link remains on ${page.route}: ${href}`);
      const targetHtml = routeToOutHtml(target);
      if (!fs.existsSync(targetHtml)) fail(`Broken internal link on ${page.route}: ${href} -> ${path.relative(projectRoot, targetHtml)}`);
      if (sitemapSet.has(target) && target !== page.route) inbound.get(target)?.add(page.route);
    }
  }
  for (const route of sitemapRoutes) {
    if (route !== '/' && (inbound.get(route)?.size || 0) === 0) fail(`Orphan sitemap route has no inbound link: ${route}`);
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

function checkNotFoundMetadata() {
  const htmlPath = path.join(outDir, '404.html');
  const html = readFileSafe(htmlPath);
  if (!html) return;
  assertMatch(html, /<meta[^>]+name="robots"[^>]+content="noindex(?:, nofollow)?"/i, '404 noindex', htmlPath);
  if (/<meta[^>]+name="robots"[^>]+content="index, follow"/i.test(html)) fail('404 page must not inherit index, follow');
  if (/<link[^>]+rel="canonical"/i.test(html)) fail('404 page must not emit a canonical to an indexable route');
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
  checkNotFoundMetadata();
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
  for (const route of sitemapRoutes) routesToValidate.add(route);
  for (const route of routesToValidate) {
    checkHtmlPage(route);
  }

  checkGeoFlow(geoRoutes);
  checkLocationHubContract(geoRoutes);
  checkProductAreaFlow();
  checkUniqueTitlesAndH1s();
  checkSchemaContracts();
  checkInternalLinksAndOrphans(sitemapRoutes);
}

if (errors.length) {
  console.error('SEO check failed:');
  for (const error of errors) {
    console.error(`- ${error}`);
  }
  process.exit(1);
}

console.log('SEO check passed.');
