import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const SITE = 'https://online.hong-sen.com';
const HISTORY = 'history/curtain-online/historical-deployments';
const POLICY = 'historical_deployment_acceptance_v1';
const LIMITATIONS = ['original_queue_bytes_unavailable', 'historical_live_manifest_unavailable', 'public_checks_performed_at_recorded_verification_time', 'current_source_not_attested', 'standard_lifecycle_not_advanced', 'continuous_publication_not_proven'];
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const assert = (ok, message) => { if (!ok) throw new Error(message); };
const json = bytes => JSON.parse(bytes.toString('utf8').replace(/^\uFEFF/, ''));
const same = (a, b) => JSON.stringify([...a].sort()) === JSON.stringify([...b].sort());
const validSha = value => typeof value === 'string' && /^[a-f0-9]{64}$/.test(value);
const decode = s => s.replace(/&amp;/g, '&').replace(/&quot;/g, '"').replace(/&#39;|&apos;/g, "'").replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&nbsp;/g, ' ').replace(/&#(\d+);/g, (_, n) => String.fromCodePoint(+n));
const text = s => decode(s.replace(/<script\b[\s\S]*?<\/script>|<style\b[\s\S]*?<\/style>/gi, '').replace(/<[^>]*>/g, ' ')).replace(/\s+/g, ' ').trim();

function timestamp(value, label, now = new Date()) {
  assert(typeof value === 'string' && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,7})?(?:Z|[+-]\d{2}:\d{2})$/.test(value), `${label}: explicit ISO timezone required`);
  const offset = value.match(/[+-](\d{2}):(\d{2})$/);
  assert(!offset || (+offset[1] <= 14 && +offset[2] <= 59 && (+offset[1] < 14 || +offset[2] === 0)), `${label}: invalid timezone offset`);
  const time = Date.parse(value);
  assert(Number.isFinite(time) && time <= +now, `${label}: invalid or future timestamp`);
  const calendar = new Date(value.slice(0, 19) + 'Z');
  assert(Number.isFinite(+calendar) && calendar.toISOString().slice(0, 19) === value.slice(0, 19), `${label}: invalid calendar date`);
  return time;
}

function contained(root, relative) {
  assert(typeof relative === 'string' && relative && !relative.includes('\\') && !path.isAbsolute(relative), 'Relative portable path required');
  assert(!relative.split('/').some(x => !x || x === '.' || x === '..'), 'Path escapes evidence root or contains dot segments');
  const result = path.resolve(root, relative);
  assert(result.startsWith(path.resolve(root) + path.sep), 'Path escapes evidence root');
  // Do not follow symlinks out of a supposedly contained evidence directory.
  let item = result;
  while (item !== path.resolve(root)) {
    if (fs.existsSync(item)) assert(!fs.lstatSync(item).isSymbolicLink(), 'Symlink evidence paths are not supported');
    item = path.dirname(item);
  }
  return result;
}

function targetUrl(value) {
  const url = new URL(value);
  assert(url.origin === SITE && !url.username && !url.password && !url.search && !url.hash && url.pathname.endsWith('/'), 'Invalid target URL');
  return url.href;
}

export function validateOriginalInputs(inputs, now = new Date()) {
  const { deployment: db, validation: vb, lifecycle: lb } = inputs;
  const deployment = json(db), validation = json(vb), lifecycle = json(lb);
  assert(deployment.schema_version === 1 && deployment.status === 'success' && deployment.dry_run === false && deployment.target_host === new URL(SITE).host, 'Successful production deployment manifest required');
  const binding = deployment.deployment_context;
  assert(binding && /^seo-geo-[a-f0-9]{16}$/.test(binding.queue_id) && /^seo-geo-v2-[a-f0-9]{24}$/.test(binding.cycle_key), 'Invalid historical identity');
  const actions = binding.action_ids;
  assert(Array.isArray(actions) && actions.length && new Set(actions).size === actions.length && actions.every(x => typeof x === 'string' && x.length > 0), 'Unique action IDs required');
  for (const doc of [validation, lifecycle]) assert(doc.queue_id === binding.queue_id && doc.cycle_key === binding.cycle_key && doc.schema_version === 2, 'Historical queue/cycle mismatch');
  assert(validation.status === 'passed' && validation.result === 'implemented' && same(validation.action_ids, actions), 'Passed validation for exact actions required');
  assert(Array.isArray(validation.action_fingerprints) && validation.action_fingerprints.length === actions.length && same(validation.action_fingerprints.map(x => x.action_id), actions) && validation.action_fingerprints.every(x => validSha(x.fingerprint) && x.action_id.endsWith('-' + x.fingerprint.slice(0, 12))), 'Action fingerprints missing or inconsistent');
  const required = ['node .agents/skills/curtain-online-seo-geo/scripts/keyword-owner-check.mjs', 'npm.cmd run build', 'npm.cmd run seo:check', 'npm.cmd run seo:preflight'];
  for (const command of required) {
    const results = validation.validation_results.filter(x => x.command === command);
    assert(results.length === 1 && results[0].status === 'passed' && results[0].exit_code === 0, `Required validation failed: ${command}`);
  }
  assert(Array.isArray(validation.source_files_after) && validation.source_files_after.length && validation.source_files_after.every(x => validSha(x.sha256) && typeof x.path === 'string'), 'Historical source hashes missing');
  const stages = lifecycle.stages;
  assert(Array.isArray(stages) && JSON.stringify(stages.map(x => x.stage)) === JSON.stringify(['implemented', 'local_validated']), 'Expected ordered incomplete historical lifecycle');
  let queueSha;
  const deployedTime = timestamp(deployment.completed_at, 'deployment.completed_at', now);
  const deploymentStarted = timestamp(deployment.generated_at, 'deployment.generated_at', now);
  assert(deploymentStarted <= deployedTime, 'Deployment completion precedes its generation');
  const validatedTime = timestamp(validation.generated_at, 'validation.generated_at', now);
  assert(validatedTime <= deploymentStarted, 'Validation occurred after deployment started');
  let previousStageTime = 0;
  for (const stage of stages) {
    const b = stage.binding, e = stage.evidence;
    assert(stage.queue_id === binding.queue_id && stage.cycle_key === binding.cycle_key && b.queue_id === binding.queue_id && b.cycle_key === binding.cycle_key && e.queue_id === binding.queue_id && e.cycle_key === binding.cycle_key, 'Lifecycle stage identity mismatch');
    assert(same([b.action_ids].flat(), actions) && same(e.action_ids, actions) && validSha(b.queue_sha256) && e.queue_sha256 === b.queue_sha256, 'Lifecycle binding mismatch');
    assert(!queueSha || queueSha === b.queue_sha256, 'Conflicting missing queue hashes');
    queueSha = b.queue_sha256;
    assert(e.validation_receipt_sha256 === sha(vb), 'Original validation receipt SHA mismatch');
    const stageTime = timestamp(stage.recorded_at, 'historical stage.recorded_at', now);
    assert(stageTime >= validatedTime && stageTime >= previousStageTime && stageTime <= deploymentStarted, 'Historical stage chronology invalid');
    previousStageTime = stageTime;
  }
  const files = deployment.files, s = deployment.summary;
  assert(Array.isArray(files) && files.length > 0 && s && Number.isInteger(s.selected) && s.selected === files.length && s.failed === 0 && s.selected === s.uploaded + s.skipped, 'Incomplete deployment summary');
  assert(new Set(files.map(x => x.relative_path)).size === files.length, 'Duplicate deployment files');
  for (const f of files) {
    assert(typeof f.relative_path === 'string' && !f.relative_path.startsWith('/') && !/[\\?#%]/.test(f.relative_path) && !f.relative_path.split('/').some(x => !x || x === '.' || x === '..'), 'Unsafe deployment file path');
    assert(validSha(f.sha256) && Number.isSafeInteger(f.size_bytes) && f.size_bytes >= 0 && ['uploaded', 'skipped_same_hash'].includes(f.result), 'Unproven deployed file');
    if (f.result === 'skipped_same_hash') assert(f.remote_sha256_before === f.sha256, 'Unproven skipped file');
  }
  assert(files.filter(x => x.result === 'uploaded').length === s.uploaded && files.filter(x => x.result === 'skipped_same_hash').length === s.skipped, 'Deployment counts disagree');
  const targets = lifecycle.target_pages.map(targetUrl);
  assert(targets.length && new Set(targets).size === targets.length, 'Unique lifecycle targets required');
  const owners = validation.registry.owners.filter(x => targets.includes(x.owner_url));
  assert(owners.length === targets.length && new Set(owners.map(x => x.owner_url)).size === targets.length, 'Target owners missing');
  for (const owner of owners) {
    assert(/^product-P\d+$/.test(owner.cluster_id), 'Only historical product deployments are supported');
    const route = new URL(owner.owner_url).pathname.slice(1) + 'index.html';
    assert(files.some(x => x.relative_path === route), 'Target HTML absent from deployment');
    assert(actions.some(x => x.startsWith(`seo-${owner.cluster_id}-`)), 'Target/action owner mismatch');
  }
  return { deployment, validation, lifecycle, targets, owners, binding: { ...binding, queue_sha256_unavailable: queueSha }, deployed_at: deployment.completed_at };
}

function tags(html, name) {
  return [...html.matchAll(new RegExp(`<${name}\\b[^>]*>`, 'gi'))].map(m => Object.fromEntries([...m[0].matchAll(/([\w-]+)\s*=\s*["']([^"']*)["']/g)].map(x => [x[1].toLowerCase(), decode(x[2])])));
}

export function validatePublicProof(original, proof, readBody, now = new Date()) {
  const verified = timestamp(proof.verified_at, 'posthoc verified_at', now);
  assert(verified >= Date.parse(original.deployed_at), 'Public verification predates deployment');
  const captures = proof.captures;
  assert(Array.isArray(captures) && new Set(captures.map(x => x.url)).size === captures.length, 'Duplicate captures');
  const checks = [];
  function body(url, status = 200) {
    const matches = captures.filter(x => x.url === url);
    assert(matches.length === 1, `Missing capture: ${url}`);
    const record = matches[0], bytes = readBody(record);
    assert(record.status === status && record.sha256 === sha(bytes) && record.size_bytes === bytes.length, `Invalid capture: ${url}`);
    const fetched = timestamp(record.fetched_at, 'capture.fetched_at', now);
    assert(fetched >= Date.parse(original.deployed_at) && fetched <= verified, 'Capture timing mismatch');
    assert(typeof record.location === 'string', 'Capture location missing');
    return bytes;
  }
  const expected = new Set([`${SITE}/robots.txt`, `${SITE}/sitemap.xml`]);
  for (const file of original.deployment.files) {
    const url = `${SITE}/${file.relative_path.split('/').map(encodeURIComponent).join('/')}`;
    expected.add(url);
    const bytes = body(url);
    assert(sha(bytes) === file.sha256 && bytes.length === file.size_bytes, `Public deployment bytes differ: ${file.relative_path}`);
  }
  const robots = body(`${SITE}/robots.txt`).toString('utf8');
  assert(/^Sitemap:\s*https:\/\/online\.hong-sen\.com\/sitemap\.xml\s*$/mi.test(robots), 'Robots sitemap declaration missing');
  const sitemap = body(`${SITE}/sitemap.xml`).toString('utf8');
  const sitemapUrls = [...sitemap.matchAll(/<loc>\s*([^<]+)\s*<\/loc>/gi)].map(x => decode(x[1]));
  assert(sitemapUrls.length, 'Sitemap empty');
  for (const owner of original.owners) {
    const url = owner.owner_url;
    expected.add(url);
    const html = body(url).toString('utf8');
    const deployed = original.deployment.files.find(x => x.relative_path === new URL(url).pathname.slice(1) + 'index.html');
    assert(sha(Buffer.from(html)) === deployed.sha256, 'Semantic target differs from uploaded HTML');
    assert(sitemapUrls.includes(url), 'Target absent from sitemap');
    const title = html.match(/<title[^>]*>([\s\S]*?)<\/title>/i), h1s = [...html.matchAll(/<h1\b[^>]*>([\s\S]*?)<\/h1>/gi)];
    assert(title && text(title[1]) && h1s.length === 1 && text(h1s[0][1]), 'Title/H1 contract failed');
    const metas = tags(html, 'meta');
    assert(metas.some(x => x.name === 'description' && x.content?.trim()), 'Meta description missing');
    assert(!metas.some(x => x.name?.toLowerCase() === 'robots' && /noindex/i.test(x.content)), 'Target noindexed');
    const canonicals = tags(html, 'link').filter(x => x.rel === 'canonical');
    assert(canonicals.length === 1 && canonicals[0].href === url, 'Canonical mismatch');
    const nodes = [];
    function walk(value) { if (Array.isArray(value)) return value.forEach(walk); if (!value || typeof value !== 'object') return; nodes.push(value); if (value['@graph']) walk(value['@graph']); }
    for (const script of html.matchAll(/<script\b[^>]*type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi)) walk(JSON.parse(script[1]));
    assert(nodes.some(x => x['@type'] === 'Product'), 'Product JSON-LD missing');
    const faqs = nodes.filter(x => x['@type'] === 'FAQPage');
    assert(faqs.length === 1 && Array.isArray(faqs[0].mainEntity) && faqs[0].mainEntity.length >= 3 && faqs[0].mainEntity.length <= 5, 'FAQPage missing or invalid');
    const visible = text(html);
    for (const entry of faqs[0].mainEntity) assert(entry.name && entry.acceptedAnswer?.text && visible.includes(text(entry.name)) && visible.includes(text(entry.acceptedAnswer.text)), 'FAQ visible/schema mismatch');
    const hrefs = tags(html, 'a').map(x => x.href).filter(Boolean);
    assert(hrefs.some(x => new URL(x, url).origin === SITE && new URL(x, url).pathname === '/calculator/'), 'Calculator CTA missing');
    for (const href of hrefs.filter(x => x.startsWith('/') || x.startsWith(SITE + '/'))) {
      const link = new URL(href, url); link.search = ''; link.hash = '';
      assert(sitemapUrls.includes(link.href), `Unresolved internal link: ${href}`);
    }
    const product = owner.cluster_id.slice('product-'.length), legacy = `${SITE}/products/${product}/`;
    expected.add(legacy);
    const redirect = captures.find(x => x.url === legacy);
    assert(redirect && [301, 308].includes(redirect.status), 'Legacy redirect status invalid');
    body(legacy, redirect.status);
    assert(new URL(redirect.location, legacy).href === url, 'Legacy redirect target mismatch');
    checks.push({ url, checks: ['http', 'deployed_html_sha256', 'title', 'meta_description', 'h1', 'canonical', 'faq_parity', 'json_ld', 'internal_links', 'cta', 'robots', 'sitemap', 'legacy_redirect'], passed: true });
  }
  assert(same(captures.map(x => x.url), [...expected]), 'Unexpected or incomplete capture set');
  return { matched_files: original.deployment.files.length, pages: checks };
}

async function publicGet(url) {
  assert(new URL(url).origin === SITE, 'Only the production origin can be fetched');
  const response = await fetch(url, { redirect: 'manual', headers: { 'Cache-Control': 'no-cache', 'Accept-Encoding': 'identity' }, signal: AbortSignal.timeout(30000) });
  return { status: response.status, location: response.headers.get('location') || '', bytes: Buffer.from(await response.arrayBuffer()) };
}

export async function acceptHistoricalDeployment({ weeklyRoot, deploymentPath, validationPath, lifecyclePath, reason, request = publicGet }) {
  assert(typeof reason === 'string' && reason.trim().length >= 12, 'An explicit acceptance reason is required');
  const guardPaths = ['latest/seo-geo-action-queue.json', 'latest/seo-geo-action-queue-state.json', 'latest/seo-geo-lifecycle-receipt.json'];
  const guarded = guardPaths.map(p => fs.existsSync(contained(weeklyRoot, p)) ? sha(fs.readFileSync(contained(weeklyRoot, p))) : null);
  const inputs = Object.fromEntries(Object.entries({ deployment: deploymentPath, validation: validationPath, lifecycle: lifecyclePath }).map(([k, p]) => [k, fs.readFileSync(contained(weeklyRoot, p))]));
  const original = validateOriginalInputs(inputs);
  const urls = new Set([`${SITE}/robots.txt`, `${SITE}/sitemap.xml`]);
  original.deployment.files.forEach(f => urls.add(`${SITE}/${f.relative_path.split('/').map(encodeURIComponent).join('/')}`));
  original.owners.forEach(o => { urls.add(o.owner_url); urls.add(`${SITE}/products/${o.cluster_id.slice(8)}/`); });
  const rawBodies = new Map(), captures = [];
  for (const url of urls) {
    const result = await request(url);
    const bytes = Buffer.from(result.bytes);
    const bodyPath = `captures/${String(captures.length).padStart(3, '0')}.bin`;
    rawBodies.set(bodyPath, bytes);
    captures.push({ url, status: result.status, location: result.location || '', fetched_at: new Date().toISOString(), body_path: bodyPath, sha256: sha(bytes), size_bytes: bytes.length });
  }
  const proof = { verified_at: new Date().toISOString(), captures };
  const checks = validatePublicProof(original, proof, record => rawBodies.get(record.body_path));
  const receipt = {
    schema_version: 1, policy: POLICY, status: 'historical_deployment_accepted', purpose: 'observation_dates_only',
    queue_id: original.binding.queue_id, cycle_key: original.binding.cycle_key, action_ids: original.binding.action_ids,
    target_pages: original.targets, deployed_at: original.deployed_at, recorded_at: new Date().toISOString(), reason,
    queue_binding: { claimed_sha256: original.binding.queue_sha256_unavailable, original_queue_available: false, content_verified: false },
    limitations: LIMITATIONS,
    original_evidence: Object.fromEntries(Object.entries(inputs).map(([key, bytes]) => [key, { path: `original/${key}.json`, source_path: { deployment: deploymentPath, validation: validationPath, lifecycle: lifecyclePath }[key], sha256: sha(bytes) }])),
    public_reverification: proof, checks
  };
  const receiptBytes = Buffer.from(JSON.stringify(receipt, null, 2) + '\n'), receiptSha = sha(receiptBytes);
  const relative = `${HISTORY}/${receipt.queue_id}/${receiptSha}`;
  const destination = contained(weeklyRoot, relative);
  assert(!fs.existsSync(destination), 'Acceptance already exists');
  const pending = contained(weeklyRoot, `${HISTORY}/.pending-${crypto.randomUUID()}`);
  fs.mkdirSync(path.join(pending, 'original'), { recursive: true });
  fs.mkdirSync(path.join(pending, 'captures'));
  try {
    for (const [key, bytes] of Object.entries(inputs)) fs.writeFileSync(path.join(pending, 'original', `${key}.json`), bytes, { flag: 'wx' });
    for (const [p, bytes] of rawBodies) fs.writeFileSync(contained(pending, p), bytes, { flag: 'wx' });
    fs.writeFileSync(path.join(pending, 'receipt.json'), receiptBytes, { flag: 'wx' });
    assert(guardPaths.every((p, i) => (fs.existsSync(contained(weeklyRoot, p)) ? sha(fs.readFileSync(contained(weeklyRoot, p))) : null) === guarded[i]), 'Current workflow changed during acceptance; retry');
    fs.mkdirSync(path.dirname(destination), { recursive: true });
    fs.renameSync(pending, destination);
  } finally {
    if (fs.existsSync(pending)) fs.rmSync(pending, { recursive: true });
  }
  return { ...readAcceptance(weeklyRoot, `${relative}/receipt.json`), receipt_sha256: receiptSha };
}

export function readAcceptance(weeklyRoot, relative) {
  const receiptPath = contained(weeklyRoot, relative), bytes = fs.readFileSync(receiptPath), receipt = json(bytes), dir = path.dirname(receiptPath);
  assert(path.basename(dir) === sha(bytes), 'Receipt content SHA mismatch');
  assert(receipt.schema_version === 1 && receipt.policy === POLICY && receipt.status === 'historical_deployment_accepted' && receipt.purpose === 'observation_dates_only', 'Unsupported acceptance receipt');
  assert(same(receipt.limitations, LIMITATIONS) && typeof receipt.reason === 'string' && receipt.reason.trim().length >= 12, 'Acceptance reason/limitations missing');
  assert(receipt.queue_binding.original_queue_available === false && receipt.queue_binding.content_verified === false, 'Receipt overstates queue verification');
  const inputs = {};
  for (const key of ['deployment', 'validation', 'lifecycle']) {
    const ref = receipt.original_evidence[key];
    inputs[key] = fs.readFileSync(contained(dir, ref.path));
    assert(sha(inputs[key]) === ref.sha256, 'Archived original SHA mismatch');
  }
  const original = validateOriginalInputs(inputs);
  assert(path.basename(path.dirname(dir)) === receipt.queue_id, 'Receipt queue directory mismatch');
  assert(receipt.queue_id === original.binding.queue_id && receipt.cycle_key === original.binding.cycle_key && receipt.queue_binding.claimed_sha256 === original.binding.queue_sha256_unavailable && same(receipt.action_ids, original.binding.action_ids) && same(receipt.target_pages, original.targets) && receipt.deployed_at === original.deployed_at, 'Receipt derived identity/date mismatch');
  assert(timestamp(receipt.recorded_at, 'receipt.recorded_at') >= timestamp(receipt.public_reverification.verified_at, 'proof.verified_at'), 'Acceptance predates verification');
  const checks = validatePublicProof(original, receipt.public_reverification, record => fs.readFileSync(contained(dir, record.body_path)));
  assert(JSON.stringify(checks) === JSON.stringify(receipt.checks), 'Receipt check summary mismatch');
  return { queue_id: receipt.queue_id, target_pages: receipt.target_pages, deployed_at: receipt.deployed_at, recorded_at: receipt.recorded_at, verified_at: receipt.public_reverification.verified_at, evidence_status: receipt.status, receipt_path: relative, matched_files: checks.matched_files };
}

export function readAcceptedHistory(weeklyRoot) {
  const root = contained(weeklyRoot, HISTORY);
  if (!fs.existsSync(root)) return [];
  const results = [];
  for (const queue of fs.readdirSync(root).filter(x => !x.startsWith('.'))) {
    assert(/^seo-geo-[a-f0-9]{16}$/.test(queue), 'Unexpected historical queue directory');
    const queueDir = contained(weeklyRoot, `${HISTORY}/${queue}`);
    for (const version of fs.readdirSync(queueDir)) {
      assert(validSha(version), 'Unexpected historical acceptance directory');
      results.push(readAcceptance(weeklyRoot, `${HISTORY}/${queue}/${version}/receipt.json`));
    }
  }
  return results;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const args = process.argv.slice(2), get = key => args[args.indexOf(key) + 1];
    assert(args.includes('--runtime-root') && get('--runtime-root'), '--runtime-root required');
    const weeklyRoot = path.resolve(get('--runtime-root'));
    if (args.includes('--read-dates')) console.log(JSON.stringify(readAcceptedHistory(weeklyRoot)));
    else {
      for (const key of ['--deployment', '--validation', '--lifecycle', '--reason']) assert(args.includes(key) && get(key), `${key} required`);
      console.log(JSON.stringify(await acceptHistoricalDeployment({ weeklyRoot, deploymentPath: get('--deployment'), validationPath: get('--validation'), lifecyclePath: get('--lifecycle'), reason: get('--reason') })));
    }
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
