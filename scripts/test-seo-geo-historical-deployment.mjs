import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import { acceptHistoricalDeployment, readAcceptance, readAcceptedHistory, validateOriginalInputs } from './seo-geo-historical-deployment.mjs';

const sha = b => crypto.createHash('sha256').update(b).digest('hex');
const bytes = obj => Buffer.from(JSON.stringify(obj));
const site = 'https://online.hong-sen.com';
const target = site + '/products/custom-curtains/';
const queue = 'seo-geo-1111111111111111', cycle = 'seo-geo-v2-111111111111111111111111', action = 'seo-product-P001-222222222222';
const faq = [1, 2, 3].map(n => ({ '@type': 'Question', name: `Question ${n}`, acceptedAnswer: { '@type': 'Answer', text: `Answer ${n}` } }));
const html = Buffer.from(`<html><head><title>Product</title><meta name="description" content="Description"><link rel="canonical" href="${target}"><script type="application/ld+json">${JSON.stringify([{ '@type': 'Product', name: 'Curtains' }, { '@type': 'FAQPage', mainEntity: faq }])}</script></head><body><h1>Product</h1>${faq.map(x => `<p>${x.name}: ${x.acceptedAnswer.text}</p>`).join('')}<a href="/calculator/?product=P001">Calculator</a></body></html>`);
const validation = {
  schema_version: 2, queue_id: queue, cycle_key: cycle, status: 'passed', result: 'implemented', action_ids: [action],
  action_fingerprints: [{ action_id: action, fingerprint: '2'.repeat(64) }],
  validation_results: ['node .agents/skills/curtain-online-seo-geo/scripts/keyword-owner-check.mjs', 'npm.cmd run build', 'npm.cmd run seo:check', 'npm.cmd run seo:preflight'].map(command => ({ command, status: 'passed', exit_code: 0 })),
  source_files_after: [{ path: 'src/example.tsx', sha256: '3'.repeat(64) }],
  registry: { owners: [{ owner_url: target, cluster_id: 'product-P001' }] }, generated_at: '2026-10-28T15:00:00Z'
};
const lifecycle = {
  schema_version: 2, queue_id: queue, cycle_key: cycle, target_pages: [target],
  stages: ['implemented', 'local_validated'].map(stage => ({ stage, queue_id: queue, cycle_key: cycle, recorded_at: '2026-10-28T15:01:00Z',
    binding: { queue_id: queue, cycle_key: cycle, queue_sha256: '4'.repeat(64), action_ids: action },
    evidence: { queue_id: queue, cycle_key: cycle, queue_sha256: '4'.repeat(64), action_ids: [action], validation_receipt_sha256: sha(bytes(validation)) }
  }))
};
const deployment = {
  schema_version: 1, status: 'success', dry_run: false, target_host: 'online.hong-sen.com', generated_at: '2026-10-28T18:39:00Z', completed_at: '2026-10-28T18:39:26.4981634Z',
  deployment_context: { queue_id: queue, cycle_key: cycle, action_ids: [action] },
  summary: { selected: 1, uploaded: 1, skipped: 0, failed: 0 },
  files: [{ relative_path: 'products/custom-curtains/index.html', sha256: sha(html), size_bytes: html.length, result: 'uploaded' }]
};
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'curtain-historical-'));
const preserved = ['seo-geo-action-queue.json', 'seo-geo-action-queue-state.json', 'seo-geo-lifecycle-receipt.json'];
const reason = 'Explicit user request to accept verifiable historical deployment evidence for observation dates.';

function originals(overrides = {}) { return { deployment: bytes(deployment), validation: bytes(validation), lifecycle: bytes(lifecycle), ...overrides }; }
function writeFixture(name) {
  const dir = path.join(root, name);
  fs.mkdirSync(path.join(dir, 'latest'), { recursive: true });
  for (const [key, b] of Object.entries(originals())) fs.writeFileSync(path.join(dir, 'latest', `${key}.json`), b);
  for (const f of preserved) fs.writeFileSync(path.join(dir, 'latest', f), bytes({ status: 'observation_only', untouched: f }));
  return dir;
}
function guard(dir) { return preserved.map(f => sha(fs.readFileSync(path.join(dir, 'latest', f)))); }
function response(url) {
  if (url === site + '/robots.txt') return { status: 200, bytes: Buffer.from(`User-agent: *\nSitemap: ${site}/sitemap.xml\n`) };
  if (url === site + '/sitemap.xml') return { status: 200, bytes: Buffer.from(`<urlset><url><loc>${target}</loc></url><url><loc>${site}/calculator/</loc></url></urlset>`) };
  if (url === target || url.endsWith('/index.html')) return { status: 200, bytes: html };
  if (url === site + '/products/P001/') return { status: 301, bytes: Buffer.alloc(0), location: target };
  throw new Error(`Unexpected URL ${url}`);
}
function run(dir, request = async url => response(url)) {
  return acceptHistoricalDeployment({ weeklyRoot: dir, deploymentPath: 'latest/deployment.json', validationPath: 'latest/validation.json', lifecyclePath: 'latest/lifecycle.json', reason, request });
}

try {
  const dir = writeFixture('valid'), before = guard(dir);
  const accepted = await run(dir);
  assert.equal(accepted.evidence_status, 'historical_deployment_accepted');
  assert.equal(accepted.deployed_at, deployment.completed_at);
  assert.notEqual(accepted.recorded_at.slice(0, 10), '2026-10-28');
  assert.deepEqual(guard(dir), before);
  assert.equal(readAcceptedHistory(dir).length, 1);
  const receiptFile = path.join(dir, accepted.receipt_path), receipt = JSON.parse(fs.readFileSync(receiptFile));
  assert.equal(receipt.queue_binding.content_verified, false);
  assert.equal(receipt.original_evidence.deployment.source_path, 'latest/deployment.json');
  assert(receipt.limitations.includes('historical_live_manifest_unavailable'));

  const invalidDeployments = [
    { ...deployment, dry_run: true }, { ...deployment, status: 'failed' }, { ...deployment, target_host: 'example.com' },
    { ...deployment, deployment_context: { ...deployment.deployment_context, queue_id: 'seo-geo-9999999999999999' } },
    { ...deployment, deployment_context: { ...deployment.deployment_context, action_ids: [action, 'extra'] } },
    { ...deployment, completed_at: '2026-10-28T18:39:26' }, { ...deployment, completed_at: '2999-01-01T00:00:00Z' },
    { ...deployment, completed_at: '2026-02-31T00:00:00Z' },
    { ...deployment, completed_at: '2026-02-30T00:00:00Z' },
    { ...deployment, completed_at: '2026-10-28T18:39:26+15:00' },
    { ...deployment, completed_at: '2026-10-28T18:39:26+14:30' },
    { ...deployment, generated_at: '2026-10-29T00:00:00Z' },
    { ...deployment, summary: { ...deployment.summary, failed: 1 } },
    { ...deployment, files: [...deployment.files, ...deployment.files], summary: { selected: 2, uploaded: 2, skipped: 0, failed: 0 } },
    { ...deployment, files: [{ ...deployment.files[0], result: 'skipped_same_size' }] },
    { ...deployment, files: [{ ...deployment.files[0], result: 'skipped_same_hash', remote_sha256_before: '5'.repeat(64) }], summary: { selected: 1, uploaded: 0, skipped: 1, failed: 0 } },
    { ...deployment, files: [{ ...deployment.files[0], relative_path: '../escape' }] },
    { ...deployment, files: [{ ...deployment.files[0], relative_path: 'other/index.html' }] }
  ];
  for (const d of invalidDeployments) assert.throws(() => validateOriginalInputs(originals({ deployment: bytes(d) })));
  assert.throws(() => validateOriginalInputs(originals({ validation: bytes({ ...validation, status: 'failed' }) })));
  const badLifecycle = structuredClone(lifecycle); badLifecycle.stages[1].evidence.validation_receipt_sha256 = '6'.repeat(64);
  assert.throws(() => validateOriginalInputs(originals({ lifecycle: bytes(badLifecycle) })), /SHA mismatch/);
  const conflicting = structuredClone(lifecycle); conflicting.stages[1].binding.queue_sha256 = '7'.repeat(64); conflicting.stages[1].evidence.queue_sha256 = '7'.repeat(64);
  assert.throws(() => validateOriginalInputs(originals({ lifecycle: bytes(conflicting) })), /Conflicting/);
  assert.throws(() => validateOriginalInputs(originals({ lifecycle: bytes({ ...lifecycle, stages: [...lifecycle.stages].reverse() }) })), /ordered/);

  const badPublicCases = [
    ['byte mismatch', url => url.endsWith('/index.html') ? { status: 200, bytes: Buffer.from('different') } : response(url)],
    ['404', url => url.endsWith('/index.html') ? { status: 404, bytes: html } : response(url)],
    ['redirect mismatch', url => url.endsWith('/P001/') ? { status: 301, bytes: Buffer.alloc(0), location: site + '/' } : response(url)],
    ['redirect temporary', url => url.endsWith('/P001/') ? { status: 302, bytes: Buffer.alloc(0), location: target } : response(url)],
    ['sitemap mismatch', url => url.endsWith('/sitemap.xml') ? { status: 200, bytes: Buffer.from('<urlset/>') } : response(url)]
  ];
  for (const [name, bad] of badPublicCases) {
    const fixture = writeFixture(name), guardBefore = guard(fixture);
    await assert.rejects(run(fixture, async url => bad(url)));
    assert.deepEqual(guard(fixture), guardBefore);
    assert.equal(readAcceptedHistory(fixture).length, 0);
  }

  for (const [name, invalidHtml] of [
    ['canonical', html.toString().replace(`rel="canonical" href="${target}"`, `rel="canonical" href="${site}/"`)],
    ['FAQ parity', html.toString().replace('<p>Question 1: Answer 1</p>', '')],
    ['noindex', html.toString().replace('</head>', '<meta name="robots" content="noindex"></head>')],
    ['CTA', html.toString().replace('/calculator/?product=P001', '/other/')]
  ]) {
    const fixture = writeFixture(name), badBytes = Buffer.from(invalidHtml), badManifest = structuredClone(deployment);
    badManifest.files[0].sha256 = sha(badBytes); badManifest.files[0].size_bytes = badBytes.length;
    fs.writeFileSync(path.join(fixture, 'latest', 'deployment.json'), bytes(badManifest));
    const beforeState = guard(fixture);
    await assert.rejects(run(fixture, async url => (url === target || url.endsWith('/index.html')) ? { status: 200, bytes: badBytes } : response(url)));
    assert.equal(readAcceptedHistory(fixture).length, 0);
    assert.deepEqual(guard(fixture), beforeState);
  }

  const raceDir = writeFixture('concurrent-change');
  let changed = false;
  await assert.rejects(run(raceDir, async url => {
    if (!changed) { fs.writeFileSync(path.join(raceDir, 'latest', preserved[0]), 'external concurrent change'); changed = true; }
    return response(url);
  }), /workflow changed/);
  assert.equal(readAcceptedHistory(raceDir).length, 0);
  assert.equal(fs.readFileSync(path.join(raceDir, 'latest', preserved[0]), 'utf8'), 'external concurrent change');

  // Tampered archived bytes, receipt fields, and path traversal must never
  // supply an observation date, even after the acceptance itself succeeded.
  const bodyPath = path.join(path.dirname(receiptFile), receipt.public_reverification.captures[0].body_path);
  const saved = fs.readFileSync(bodyPath); fs.writeFileSync(bodyPath, 'tampered');
  assert.throws(() => readAcceptedHistory(dir), /Invalid capture/);
  fs.writeFileSync(bodyPath, saved);
  const changedReceipt = structuredClone(receipt); changedReceipt.deployed_at = '2026-10-01T00:00:00Z';
  fs.writeFileSync(receiptFile, bytes(changedReceipt));
  assert.throws(() => readAcceptance(dir, accepted.receipt_path), /Receipt content SHA/);
  fs.writeFileSync(receiptFile, JSON.stringify(receipt, null, 2) + '\n');
  assert.throws(() => readAcceptance(dir, '../escape.json'), /escapes/);
  assert.equal(readAcceptedHistory(dir).length, 1);
  const queueDir = path.dirname(path.dirname(receiptFile)), wrongQueueDir = path.join(path.dirname(queueDir), 'seo-geo-9999999999999999');
  fs.renameSync(queueDir, wrongQueueDir);
  assert.throws(() => readAcceptedHistory(dir), /queue directory/);
  fs.renameSync(wrongQueueDir, queueDir);
  assert.deepEqual(guard(dir), before);
  console.log(`PASS historical deployment acceptance: ${invalidDeployments.length + 4} invalid original proofs; ${badPublicCases.length + 4} public failures; concurrent-change rejection, immutable evidence, workflow isolation, original date, tamper/path rejection`);
} finally {
  fs.rmSync(root, { recursive: true, force: true });
}
