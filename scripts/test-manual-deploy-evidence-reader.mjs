import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { readManualDeploymentEvidence } from './manual-deploy-evidence-reader.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const SCRIPT = path.join(HERE, 'manual-deploy-evidence-reader.mjs');
const NOW = new Date('2026-11-06T00:00:00Z');
const WEEKLY_LOGICAL = 'Weekly SOP/history/curtain-online/manual-deployments';
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const jsonBytes = value => Buffer.from(`${JSON.stringify(value, null, 2)}\n`);

function writeJson(file, value) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, jsonBytes(value));
}

function deepClone(value) {
  return JSON.parse(JSON.stringify(value));
}

function createFixture({ withSidecar = false, manifestName = '2026-11-04-mobile-calculator-release.json', liveName = '2026-11-04-mobile-calculator-live-files.json' } = {}) {
  const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'manual-deploy-reader-'));
  const weeklyRoot = path.join(tempRoot, 'runtime');
  const actualEvidenceDir = path.join(weeklyRoot, 'history', 'curtain-online', 'manual-deployments');
  fs.mkdirSync(actualEvidenceDir, { recursive: true });
  const manifestLogicalPath = `${WEEKLY_LOGICAL}/${manifestName}`;
  const liveLogicalPath = `${WEEKLY_LOGICAL}/${liveName}`;
  const manifestPath = path.join(actualEvidenceDir, manifestName);
  const livePath = path.join(actualEvidenceDir, liveName);
  const files = [
    { relative_path: 'alpha/index.html', bytes: Buffer.from('<html><body>alpha output</body></html>'), result: 'uploaded' },
    { relative_path: 'beta/index.html', bytes: Buffer.from('<html><body>same deployed beta</body></html>'), result: 'skipped_same_hash' },
    { relative_path: '404.html', bytes: Buffer.from('<html><body>404</body></html>'), result: 'uploaded' },
    { relative_path: '_next/static/app.js', bytes: Buffer.from('window.fixture = true;'), result: 'uploaded' },
  ].map(file => {
    const digest = sha(file.bytes);
    return {
      relative_path: file.relative_path,
      size_bytes: file.bytes.length,
      sha256: digest,
      result: file.result,
      remote_size_before: file.result === 'skipped_same_hash' ? file.bytes.length : null,
      remote_sha256_before: file.result === 'skipped_same_hash' ? digest : null,
      attempts: file.result === 'uploaded' ? 1 : 0,
      error: null,
    };
  });
  const manifest = {
    schema_version: 1,
    status: 'success',
    generated_at: '2026-11-04T10:00:00.000Z',
    completed_at: '2026-11-04T10:05:00.000Z',
    deploy_mode: 'quick',
    dry_run: false,
    force: false,
    target_host: 'online.hong-sen.com',
    ftp_host: 'ftp.hong-sen.com',
    remote_root: 'online.hong-sen.com',
    local_root: 'C:/fixture/out',
    deployment_context: null,
    deploy_plan: null,
    summary: { selected: 4, uploaded: 3, skipped: 1, failed: 0, bytes_uploaded: files.filter(file => file.result === 'uploaded').reduce((total, file) => total + file.size_bytes, 0) },
    files,
  };
  const manifestBytes = jsonBytes(manifest);
  fs.writeFileSync(manifestPath, manifestBytes);

  const liveFiles = {
    kind: 'manual_public_file_verification',
    generated_at: '2026-11-04T10:07:00.000Z',
    started_at: '2026-11-04T10:06:00.000Z',
    manifest_path: manifestLogicalPath,
    manifest_sha256: sha(manifestBytes),
    checks: { selected: 4, matched: 4, mismatched_or_redirected: 0 },
    files: files.map(file => ({
      path: file.relative_path,
      status: 200,
      bytes: file.size_bytes,
      local_sha256: file.sha256,
      response_sha256: file.sha256,
      matches: true,
      location: null,
      attempts: 1,
    })),
  };
  writeJson(livePath, liveFiles);

  const sidecarName = `${manifestName.slice(0, -'.json'.length)}.page-classification.json`;
  const sidecarPath = path.join(actualEvidenceDir, sidecarName);
  let sidecar = null;
  if (withSidecar) {
    sidecar = {
      schema_version: 1,
      kind: 'manual_deployment_page_classification',
      reviewer_kind: 'ai_assisted',
      reviewed_by: 'Codex (AI-assisted; not a human attestation)',
      reviewed_at: '2026-11-04T10:08:00.000Z',
      manifest_path: manifestLogicalPath,
      manifest_sha256: sha(manifestBytes),
      live_files_path: liveLogicalPath,
      live_files_sha256: sha(jsonBytes(liveFiles)),
      limitations: ['source_bytes_not_bound', 'classification_is_ai_assisted_not_human_attestation'],
      pages: [
        { path: 'alpha/index.html', classification: 'main_content_changed', rationale: 'The recorded page review identifies a visible core content change.' },
        { path: 'beta/index.html', classification: 'main_content_unchanged', rationale: 'This output was hash skipped and no new page bytes were deployed.' },
        { path: '404.html', classification: 'unknown', rationale: 'The available review evidence does not determine a semantic content change.' },
      ],
    };
    writeJson(sidecarPath, sidecar);
  }

  return {
    tempRoot,
    weeklyRoot,
    actualEvidenceDir,
    manifestPath,
    livePath,
    sidecarPath,
    manifest,
    liveFiles,
    sidecar,
    manifestLogicalPath,
    liveLogicalPath,
    read: overrides => readManualDeploymentEvidence({ weeklyRoot, now: NOW, ...overrides }),
    cleanup: () => fs.rmSync(tempRoot, { recursive: true, force: true }),
  };
}

function testFixture(t, options) {
  const fixture = createFixture(options);
  t.after(fixture.cleanup);
  return fixture;
}

function expectRejected(fixture, regex, operation = () => fixture.read()) {
  assert.throws(operation, regex);
}

test('missing manual history returns a passed empty result for isolated legacy runtime roots', t => {
  const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'manual-deploy-reader-empty-'));
  t.after(() => fs.rmSync(tempRoot, { recursive: true, force: true }));
  const weeklyRoot = path.join(tempRoot, 'runtime');
  fs.mkdirSync(weeklyRoot);
  const result = readManualDeploymentEvidence({ weeklyRoot, now: NOW });
  assert.equal(result.status, 'passed');
  assert.deepEqual(result.date_candidates, []);
  assert.equal(result.empty_reason, 'manual_deployments_directory_missing');
});

test('existing but empty manual history fails closed', t => {
  const fixture = testFixture(t);
  for (const file of fs.readdirSync(fixture.actualEvidenceDir)) fs.rmSync(path.join(fixture.actualEvidenceDir, file));
  expectRejected(fixture, /No JSON evidence files/);
});

test('valid mobile-calculator-release pairing emits only uploaded HTML candidates and keeps unknown blocked', t => {
  const fixture = testFixture(t);
  const result = fixture.read();
  assert.equal(result.contract, 'manual_deploy_evidence_reader_v1');
  assert.equal(result.status, 'passed');
  assert.equal(result.summary.deployment_count, 1);
  assert.equal(result.date_candidates.length, 2);
  assert.deepEqual(result.date_candidates.map(item => item.page_path), ['404.html', 'alpha/index.html']);
  const alpha = result.date_candidates.find(item => item.page_path === 'alpha/index.html');
  const notFound = result.date_candidates.find(item => item.page_path === '404.html');
  assert.equal(alpha.page_url, 'https://online.hong-sen.com/alpha/');
  assert.equal(alpha.candidate_day_taipei, '2026-11-04');
  assert.equal(alpha.classification.status, 'unknown');
  assert.equal(alpha.classification_resolved, false);
  assert.equal(alpha.cooldown_decision, 'blocked_unknown');
  assert.equal(notFound.page_url, 'https://online.hong-sen.com/404.html');
  assert.equal(notFound.cooldown_decision, 'blocked_unknown');
  assert.equal(result.date_candidates.some(item => item.page_path === 'beta/index.html'), false, 'skipped_same_hash files must not create date candidates');
  assert.equal(result.evidence[0].manifest.path, fixture.manifestLogicalPath);
  assert.equal(result.evidence[0].live_files.path, fixture.liveLogicalPath);
  assert.equal(result.evidence[0].live_files.document.manifest_sha256, result.evidence[0].manifest.sha256);
  assert.equal(alpha.evidence.manifest_file.sha256, alpha.evidence.live_file.response_sha256);
  assert.equal(alpha.evidence.live_file.local_sha256, alpha.evidence.live_file.response_sha256);
  assert.equal(alpha.evidence.classification_sidecar.status, 'missing');
});

test('sidecar classifications only enable uploaded main-content dates and expose AI-assisted limits', t => {
  const fixture = testFixture(t, { withSidecar: true });
  const result = fixture.read();
  const alpha = result.date_candidates.find(item => item.page_path === 'alpha/index.html');
  const notFound = result.date_candidates.find(item => item.page_path === '404.html');
  assert.equal(alpha.classification.status, 'main_content_changed');
  assert.equal(alpha.classification.reviewer_kind, 'ai_assisted');
  assert.equal(alpha.classification_resolved, true);
  assert.equal(alpha.cooldown_decision, 'eligible');
  assert.equal(notFound.classification.status, 'unknown');
  assert.equal(notFound.cooldown_decision, 'blocked_unknown');
  assert.equal(result.summary.cooldown_eligible_count, 1);
  assert.equal(result.evidence[0].page_classification.document.limitations.includes('source_bytes_not_bound'), true);
  assert.equal(result.evidence_summaries[0].page_classification.path, `${WEEKLY_LOGICAL}/2026-11-04-mobile-calculator-release.page-classification.json`);
  assert.equal(result.evidence_summaries[0].page_classification.sha256, sha(jsonBytes(fixture.sidecar)));
});

test('an all-skipped deployment creates no date candidates but remains represented in evidence summaries', t => {
  const fixture = testFixture(t);
  const manifest = deepClone(fixture.manifest);
  manifest.summary.uploaded = 0;
  manifest.summary.skipped = manifest.summary.selected;
  manifest.summary.bytes_uploaded = 0;
  for (const file of manifest.files) {
    file.result = 'skipped_same_hash';
    file.remote_size_before = file.size_bytes;
    file.remote_sha256_before = file.sha256;
    file.attempts = 0;
  }
  const manifestBytes = jsonBytes(manifest);
  fs.writeFileSync(fixture.manifestPath, manifestBytes);
  const live = deepClone(fixture.liveFiles);
  live.manifest_sha256 = sha(manifestBytes);
  writeJson(fixture.livePath, live);
  const result = fixture.read();
  assert.deepEqual(result.date_candidates, []);
  assert.equal(result.summary.page_candidate_count, 0);
  assert.equal(result.evidence_summaries.length, 1);
  assert.equal(result.evidence_summaries[0].manifest.path, fixture.manifestLogicalPath);
  assert.equal(result.evidence_summaries[0].live_files.path, fixture.liveLogicalPath);
  assert.equal(result.evidence_summaries[0].page_classification.status, 'missing');
});

test('CLI emits compact JSON on stdout for a relocated weekly root and retains logical paths', t => {
  const fixture = testFixture(t);
  const child = spawnSync(process.execPath, [SCRIPT, '--weekly-root', fixture.weeklyRoot], { encoding: 'utf8' });
  assert.equal(child.status, 0, child.stderr);
  const output = JSON.parse(child.stdout);
  assert.equal(output.status, 'passed');
  assert.equal(output.evidence, undefined, 'CLI should not include the full 487-file evidence documents');
  assert.equal(output.date_candidates[0].evidence.manifest_path, fixture.manifestLogicalPath);
  assert.equal(output.date_candidates[0].evidence.live_files_path, fixture.liveLogicalPath);
  assert.equal(output.evidence_summaries.length, 1);
  assert.deepEqual(output.evidence_summaries[0].manifest, {
    path: fixture.manifestLogicalPath,
    sha256: sha(jsonBytes(fixture.manifest)),
    size_bytes: jsonBytes(fixture.manifest).length,
  });
  assert.equal(output.evidence_summaries[0].live_files.path, fixture.liveLogicalPath);
  assert.equal(output.evidence_summaries[0].page_classification.status, 'missing');
  assert.equal(output.evidence_summaries[0].page_classification.sha256, null);
});

test('CLI returns a machine-readable rejection with a non-zero status', t => {
  const fixture = testFixture(t);
  const manifest = deepClone(fixture.manifest);
  manifest.status = 'failed';
  writeJson(fixture.manifestPath, manifest);
  const child = spawnSync(process.execPath, [SCRIPT, '--weekly-root', fixture.weeklyRoot], { encoding: 'utf8' });
  assert.equal(child.status, 1);
  const output = JSON.parse(child.stdout);
  assert.equal(output.status, 'rejected');
  assert.match(output.error, /successful non-dry-run/);
});

for (const [name, mutate, expected] of [
  ['failed status', manifest => { manifest.status = 'failed'; }, /successful non-dry-run/],
  ['dry run', manifest => { manifest.dry_run = true; manifest.status = 'dry_run'; }, /successful non-dry-run/],
  ['wrong production host', manifest => { manifest.target_host = 'example.com'; }, /target_host/],
  ['failed summary', manifest => { manifest.summary.failed = 1; }, /summary reports failed/],
  ['summary count mismatch', manifest => { manifest.summary.selected += 1; }, /summary counts/],
  ['unsafe deployment path', manifest => { manifest.files[0].relative_path = '../escape.html'; }, /traversing segment/],
]) {
  test(`rejects ${name}`, t => {
    const fixture = testFixture(t);
    const manifest = deepClone(fixture.manifest);
    mutate(manifest);
    writeJson(fixture.manifestPath, manifest);
    expectRejected(fixture, expected);
  });
}

for (const [name, mutate, expected] of [
  ['wrong manifest SHA binding', live => { live.manifest_sha256 = '0'.repeat(64); }, /manifest SHA/],
  ['non-200 HTTP status', live => { live.files[0].status = 301; }, /HTTP status is not 200/],
  ['local SHA mismatch', live => { live.files[0].local_sha256 = '0'.repeat(64); }, /local SHA differs/],
  ['response SHA mismatch', live => { live.files[0].response_sha256 = '0'.repeat(64); }, /response SHA differs/],
  ['response byte mismatch', live => { live.files[0].bytes += 1; }, /response byte count/],
  ['redirect location', live => { live.files[0].location = '/elsewhere'; }, /redirect location/],
  ['missing live file record', live => { live.files.pop(); }, /files is incomplete/],
  ['unmatched live file path', live => { live.files[0].path = 'unknown/index.html'; }, /unmatched live file/],
  ['traversal manifest reference', live => { live.manifest_path = '../outside.json'; }, /portable relative path|traversing segment/],
]) {
  test(`rejects ${name}`, t => {
    const fixture = testFixture(t);
    const live = deepClone(fixture.liveFiles);
    mutate(live);
    writeJson(fixture.livePath, live);
    expectRejected(fixture, expected);
  });
}

test('rejects a missing live-files counterpart', t => {
  const fixture = testFixture(t);
  fs.rmSync(fixture.livePath);
  expectRejected(fixture, /expected exactly one paired live-files record/);
});

test('rejects unmatched live-files evidence', t => {
  const fixture = testFixture(t);
  const orphan = deepClone(fixture.liveFiles);
  orphan.manifest_path = `${WEEKLY_LOGICAL}/missing.json`;
  writeJson(path.join(fixture.actualEvidenceDir, 'orphan-live-files.json'), orphan);
  expectRejected(fixture, /expected exactly one paired live-files record|Unmatched live-files/);
});

test('rejects corrupt JSON evidence', t => {
  const fixture = testFixture(t);
  fs.writeFileSync(fixture.manifestPath, '{broken');
  expectRejected(fixture, /invalid JSON/);
});

for (const [name, mutate, expected] of [
  ['manifest SHA mismatch', sidecar => { sidecar.manifest_sha256 = '0'.repeat(64); }, /deployment manifest binding mismatch/],
  ['live SHA mismatch', sidecar => { sidecar.live_files_sha256 = '0'.repeat(64); }, /live evidence binding mismatch/],
  ['incomplete page coverage', sidecar => { sidecar.pages.pop(); }, /cover each deployed HTML file/],
  ['duplicate page classification', sidecar => { sidecar.pages.push(deepClone(sidecar.pages[0])); }, /cover each deployed HTML file|duplicate page classification/],
  ['invalid classification value', sidecar => { sidecar.pages[0].classification = 'maybe'; }, /invalid classification/],
  ['missing rationale', sidecar => { sidecar.pages[0].rationale = ''; }, /rationale is required/],
  ['wrong reviewer kind', sidecar => { sidecar.reviewer_kind = 'human'; }, /reviewer_kind/],
  ['missing source limitation', sidecar => { sidecar.limitations = []; }, /source bytes are not bound/],
  ['changed classification for a hash-skipped HTML file', sidecar => { sidecar.pages.find(page => page.path === 'beta/index.html').classification = 'main_content_changed'; }, /skipped_same_hash page cannot be classified/],
]) {
  test(`rejects sidecar with ${name}`, t => {
    const fixture = testFixture(t, { withSidecar: true });
    const sidecar = deepClone(fixture.sidecar);
    mutate(sidecar);
    writeJson(fixture.sidecarPath, sidecar);
    expectRejected(fixture, expected);
  });
}

test('rejects orphan classification sidecars', t => {
  const fixture = testFixture(t);
  const orphan = {
    schema_version: 1,
    kind: 'manual_deployment_page_classification',
    reviewer_kind: 'ai_assisted',
    reviewed_by: 'Codex (AI-assisted)',
    reviewed_at: '2026-11-04T10:08:00.000Z',
    manifest_path: `${WEEKLY_LOGICAL}/missing.json`,
    manifest_sha256: '0'.repeat(64),
    live_files_path: `${WEEKLY_LOGICAL}/missing-live-files.json`,
    live_files_sha256: '0'.repeat(64),
    pages: [],
  };
  writeJson(path.join(fixture.actualEvidenceDir, 'orphan.page-classification.json'), orphan);
  expectRejected(fixture, /Unmatched classification sidecar/);
});
