import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const SITE_ORIGIN = 'https://online.hong-sen.com';
const CONTRACT = 'manual_deploy_evidence_reader_v1';
const SIDECAR_KIND = 'manual_deployment_page_classification';
const SHA256_RE = /^[a-f0-9]{64}$/;
const DEFAULT_WEEKLY_ROOT = 'Weekly SOP';
const DEFAULT_MANUAL_DIR = 'history/curtain-online/manual-deployments';
const LOGICAL_WEEKLY_PREFIX = 'Weekly SOP/';

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function sha256(bytes) {
  return crypto.createHash('sha256').update(bytes).digest('hex');
}

function isObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function requiredObject(value, label) {
  assert(isObject(value), `${label} must be an object`);
  return value;
}

function validSha(value) {
  return typeof value === 'string' && SHA256_RE.test(value);
}

function requiredPortablePath(value, label) {
  assert(typeof value === 'string' && value.length > 0, `${label} must be a non-empty path`);
  assert(!value.includes('\\') && !value.startsWith('/') && !/^[a-zA-Z]:/.test(value), `${label} must be a portable relative path`);
  assert(!/[\0?#%]/.test(value), `${label} contains a forbidden character`);
  const segments = value.split('/');
  assert(segments.every(segment => segment && segment !== '.' && segment !== '..'), `${label} contains an empty or traversing segment`);
  return value;
}

function containedPath(root, relative, label = 'Evidence path', { mustExist = true } = {}) {
  const rel = requiredPortablePath(relative, label);
  const rootPath = path.resolve(root);
  const result = path.resolve(rootPath, ...rel.split('/'));
  const back = path.relative(rootPath, result);
  assert(back && back !== '..' && !back.startsWith(`..${path.sep}`) && !path.isAbsolute(back), `${label} escapes its evidence root`);

  let current = rootPath;
  for (const segment of rel.split('/')) {
    current = path.join(current, segment);
    if (!fs.existsSync(current)) {
      assert(!mustExist, `${label} is missing`);
      continue;
    }
    const stat = fs.lstatSync(current);
    assert(!stat.isSymbolicLink(), `${label} must not pass through a symlink`);
  }
  if (mustExist) assert(fs.existsSync(result), `${label} is missing`);
  return result;
}

function timestamp(value, label, now) {
  assert(typeof value === 'string' && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,9})?(?:Z|[+-]\d{2}:\d{2})$/.test(value), `${label} must be an ISO timestamp with an explicit timezone`);
  const offset = value.match(/[+-](\d{2}):(\d{2})$/);
  assert(!offset || (+offset[1] <= 14 && +offset[2] <= 59 && (+offset[1] < 14 || +offset[2] === 0)), `${label} has an invalid timezone offset`);
  const milliseconds = Date.parse(value);
  assert(Number.isFinite(milliseconds) && milliseconds <= +now, `${label} is invalid or in the future`);
  const calendar = new Date(`${value.slice(0, 19)}Z`);
  assert(Number.isFinite(+calendar) && calendar.toISOString().slice(0, 19) === value.slice(0, 19), `${label} has an invalid calendar date`);
  return milliseconds;
}

function parseJsonBytes(bytes, label) {
  let value;
  try {
    value = JSON.parse(bytes.toString('utf8').replace(/^\uFEFF/, ''));
  } catch (error) {
    throw new Error(`${label} contains invalid JSON: ${error.message}`);
  }
  return requiredObject(value, label);
}

function readRegularFile(root, relative, label) {
  const absolute = containedPath(root, relative, label);
  const stat = fs.lstatSync(absolute);
  assert(stat.isFile(), `${label} must be a regular file`);
  const bytes = fs.readFileSync(absolute);
  return { absolute, bytes, document: parseJsonBytes(bytes, label), sha256: sha256(bytes), size_bytes: bytes.length };
}

function resolveManualDirectory(weeklyRoot, manualDeploymentsDir) {
  const candidate = path.isAbsolute(manualDeploymentsDir)
    ? path.resolve(manualDeploymentsDir)
    : path.resolve(weeklyRoot, manualDeploymentsDir);
  const relative = path.relative(weeklyRoot, candidate);
  assert(relative && relative !== '..' && !relative.startsWith(`..${path.sep}`) && !path.isAbsolute(relative), 'Manual deployments directory must be inside the weekly root');
  let current = weeklyRoot;
  for (const segment of relative.split(path.sep)) {
    current = path.join(current, segment);
    let stat;
    try {
      stat = fs.lstatSync(current);
    } catch (error) {
      if (error.code === 'ENOENT') return null;
      throw error;
    }
    assert(!stat.isSymbolicLink(), 'Manual deployments path must not pass through a symlink');
    if (current !== candidate) assert(stat.isDirectory(), 'Manual deployments parent path must be a directory');
  }
  assert(fs.lstatSync(candidate).isDirectory(), 'Manual deployments path must be a real directory');
  return candidate;
}

function isDryRunArtifact(name) {
  return /(?:\.|-)dryrun\.json$/i.test(name);
}

function isLiveFilesArtifact(name) {
  return /-live-files\.json$/i.test(name);
}

function isClassificationArtifact(name) {
  return name.endsWith('.page-classification.json');
}

function sidecarNameFor(manifestName) {
  return `${manifestName.slice(0, -'.json'.length)}.page-classification.json`;
}

function summarizeEvidence(items) {
  return items.map(item => ({
    evidence_id: item.evidence_id,
    manifest: { path: item.manifest.path, sha256: item.manifest.sha256, size_bytes: item.manifest.size_bytes },
    live_files: { path: item.live_files.path, sha256: item.live_files.sha256, size_bytes: item.live_files.size_bytes },
    page_classification: item.page_classification.status === 'provided'
      ? { status: 'provided', path: item.page_classification.path, sha256: item.page_classification.sha256, size_bytes: item.page_classification.size_bytes, reviewer_kind: item.page_classification.document.reviewer_kind }
      : { status: 'missing', expected_path: item.page_classification.expected_path, sha256: null },
  }));
}

function validateManifest(manifest, bytes, label, now) {
  assert(manifest.schema_version === 1, `${label}: unsupported schema_version`);
  assert(manifest.status === 'success' && manifest.dry_run === false, `${label}: a successful non-dry-run deployment is required`);
  assert(manifest.target_host === new URL(SITE_ORIGIN).host, `${label}: target_host does not match the production host`);
  const generated = timestamp(manifest.generated_at, `${label}.generated_at`, now);
  const completed = timestamp(manifest.completed_at, `${label}.completed_at`, now);
  assert(generated <= completed, `${label}: completion precedes generation`);

  const summary = requiredObject(manifest.summary, `${label}.summary`);
  const files = manifest.files;
  assert(Array.isArray(files) && files.length > 0, `${label}.files must be a non-empty array`);
  for (const field of ['selected', 'uploaded', 'skipped', 'failed']) {
    assert(Number.isSafeInteger(summary[field]) && summary[field] >= 0, `${label}.summary.${field} must be a non-negative integer`);
  }
  assert(summary.failed === 0, `${label}: summary reports failed files`);
  assert(summary.selected === files.length && summary.selected === summary.uploaded + summary.skipped, `${label}: summary counts do not match the file records`);
  assert(Number.isSafeInteger(summary.bytes_uploaded) && summary.bytes_uploaded >= 0, `${label}.summary.bytes_uploaded is invalid`);

  const seenPaths = new Set();
  let uploaded = 0;
  let skipped = 0;
  for (const rawFile of files) {
    const file = requiredObject(rawFile, `${label}.files[]`);
    const relativePath = requiredPortablePath(file.relative_path, `${label}.files[].relative_path`);
    assert(!seenPaths.has(relativePath), `${label}: duplicate deployment path ${relativePath}`);
    seenPaths.add(relativePath);
    assert(validSha(file.sha256), `${label}: invalid deploy SHA for ${relativePath}`);
    assert(Number.isSafeInteger(file.size_bytes) && file.size_bytes >= 0, `${label}: invalid file size for ${relativePath}`);
    assert(file.error === null || file.error === undefined, `${label}: file error recorded for ${relativePath}`);
    if (file.result === 'uploaded') uploaded += 1;
    else if (file.result === 'skipped_same_hash') {
      skipped += 1;
      assert(file.remote_sha256_before === file.sha256, `${label}: skipped file has no matching remote SHA for ${relativePath}`);
      assert(file.remote_size_before === file.size_bytes, `${label}: skipped file has no matching remote size for ${relativePath}`);
    } else throw new Error(`${label}: unsupported deployment result for ${relativePath}`);
  }
  assert(uploaded === summary.uploaded && skipped === summary.skipped, `${label}: result counts disagree with summary`);
  assert(sha256(bytes).length === 64, `${label}: manifest bytes could not be hashed`);
  return { generated_ms: generated, completed_ms: completed, htmlFiles: files.filter(file => file.relative_path.toLowerCase().endsWith('.html')) };
}

function validateLiveFiles(live, liveBytes, liveLabel, manifest, manifestBytes, manifestPath, manifestLabel, manifestInfo, now) {
  assert(live.kind === 'manual_public_file_verification', `${liveLabel}: unsupported live evidence kind`);
  assert(live.manifest_path === manifestPath, `${liveLabel}: manifest_path does not identify the paired deployment manifest`);
  const manifestSha = sha256(manifestBytes);
  assert(live.manifest_sha256 === manifestSha, `${liveLabel}: manifest SHA does not bind the exact manifest bytes`);
  const started = timestamp(live.started_at, `${liveLabel}.started_at`, now);
  const generated = timestamp(live.generated_at, `${liveLabel}.generated_at`, now);
  assert(started >= manifestInfo.completed_ms && generated >= started, `${liveLabel}: live verification timing is inconsistent`);

  const checks = requiredObject(live.checks, `${liveLabel}.checks`);
  assert(checks.selected === manifest.files.length && checks.matched === manifest.files.length && checks.mismatched_or_redirected === 0, `${liveLabel}: not all deployed files were matched without redirects`);
  assert(Array.isArray(live.files) && live.files.length === manifest.files.length, `${liveLabel}.files is incomplete`);

  const deployByPath = new Map(manifest.files.map(file => [file.relative_path, file]));
  const seen = new Set();
  for (const rawRecord of live.files) {
    const record = requiredObject(rawRecord, `${liveLabel}.files[]`);
    const relativePath = requiredPortablePath(record.path, `${liveLabel}.files[].path`);
    assert(!seen.has(relativePath), `${liveLabel}: duplicate live evidence path ${relativePath}`);
    seen.add(relativePath);
    const deployFile = deployByPath.get(relativePath);
    assert(deployFile, `${liveLabel}: unmatched live file ${relativePath}`);
    assert(record.status === 200, `${liveLabel}: HTTP status is not 200 for ${relativePath}`);
    assert(record.bytes === deployFile.size_bytes, `${liveLabel}: response byte count differs from deploy bytes for ${relativePath}`);
    assert(record.local_sha256 === deployFile.sha256, `${liveLabel}: local SHA differs from deploy SHA for ${relativePath}`);
    assert(record.response_sha256 === deployFile.sha256, `${liveLabel}: response SHA differs from deploy SHA for ${relativePath}`);
    assert(record.matches === true, `${liveLabel}: live file is not marked as matched for ${relativePath}`);
    assert(record.location === null || record.location === '', `${liveLabel}: unexpected redirect location for ${relativePath}`);
  }
  assert(seen.size === deployByPath.size, `${liveLabel}: live evidence does not cover every deployment file`);
  assert(sha256(liveBytes).length === 64, `${liveLabel}: live evidence bytes could not be hashed`);
  return { generated_ms: generated, manifest_sha256: manifestSha };
}

function taipeiDate(isoTimestamp) {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Asia/Taipei', year: 'numeric', month: '2-digit', day: '2-digit',
  }).formatToParts(new Date(isoTimestamp));
  const values = Object.fromEntries(parts.map(part => [part.type, part.value]));
  return `${values.year}-${values.month}-${values.day}`;
}

function pageUrl(relativePath) {
  const segments = relativePath.split('/');
  const isIndex = segments.at(-1).toLowerCase() === 'index.html';
  if (isIndex) segments.pop();
  const encoded = segments.map(segment => encodeURIComponent(segment));
  const pathname = `/${encoded.join('/')}${isIndex && segments.length ? '/' : ''}`;
  return new URL(pathname, SITE_ORIGIN).href;
}

function validateClassificationSidecar(sidecar, sidecarBytes, sidecarPath, expectedPath, manifestPath, manifestHash, livePath, liveHash, htmlFiles, label, now) {
  assert(sidecarPath === expectedPath, `${label}: classification sidecar has an unexpected filename`);
  assert(sidecar.schema_version === 1 && sidecar.kind === SIDECAR_KIND, `${label}: unsupported classification sidecar schema`);
  assert(sidecar.reviewer_kind === 'ai_assisted', `${label}.reviewer_kind must identify AI-assisted classification`);
  assert(Array.isArray(sidecar.limitations) && sidecar.limitations.includes('source_bytes_not_bound'), `${label}: must disclose that source bytes are not bound to the deployment`);
  assert(typeof sidecar.reviewed_by === 'string' && sidecar.reviewed_by.trim().length >= 2, `${label}.reviewed_by is required`);
  const reviewed = timestamp(sidecar.reviewed_at, `${label}.reviewed_at`, now);
  assert(sidecar.manifest_path === manifestPath && sidecar.manifest_sha256 === manifestHash, `${label}: deployment manifest binding mismatch`);
  assert(sidecar.live_files_path === livePath && sidecar.live_files_sha256 === liveHash, `${label}: live evidence binding mismatch`);
  assert(Array.isArray(sidecar.pages), `${label}.pages must be an array`);
  const expected = new Set(htmlFiles.map(file => file.relative_path));
  assert(sidecar.pages.length === expected.size, `${label}: page classifications must cover each deployed HTML file exactly once`);
  const pages = new Map();
  for (const rawPage of sidecar.pages) {
    const record = requiredObject(rawPage, `${label}.pages[]`);
    const pagePath = requiredPortablePath(record.path, `${label}.pages[].path`);
    assert(expected.has(pagePath), `${label}: classification references an undeployed HTML file ${pagePath}`);
    assert(!pages.has(pagePath), `${label}: duplicate page classification ${pagePath}`);
    assert(['main_content_changed', 'main_content_unchanged', 'unknown'].includes(record.classification), `${label}: invalid classification for ${pagePath}`);
    assert(typeof record.rationale === 'string' && record.rationale.trim().length >= 12, `${label}: rationale is required for ${pagePath}`);
    const deployFile = htmlFiles.find(file => file.relative_path === pagePath);
    assert(deployFile, `${label}: page deployment record is missing for ${pagePath}`);
    assert(!(deployFile.result === 'skipped_same_hash' && record.classification === 'main_content_changed'), `${label}: skipped_same_hash page cannot be classified as a main-content deployment event (${pagePath})`);
    pages.set(pagePath, { classification: record.classification, rationale: record.rationale.trim() });
  }
  assert(pages.size === expected.size, `${label}: one or more deployed HTML pages are unclassified`);
  return { pages, reviewed_ms: reviewed, sha256: sha256(sidecarBytes), reviewer_kind: sidecar.reviewer_kind, reviewed_by: sidecar.reviewed_by };
}

function listEvidenceFiles(weeklyRoot, manualDir, now) {
  const files = fs.readdirSync(manualDir, { withFileTypes: true });
  const docs = [];
  for (const entry of files) {
    if (!entry.name.toLowerCase().endsWith('.json')) continue;
    assert(entry.isFile() && !entry.isSymbolicLink(), `Evidence entry must be a regular file: ${entry.name}`);
    const absolute = path.join(manualDir, entry.name);
    const relativePath = path.relative(weeklyRoot, absolute).split(path.sep).join('/');
    requiredPortablePath(relativePath, `Evidence filename ${entry.name}`);
    const logicalPath = `${LOGICAL_WEEKLY_PREFIX}${relativePath}`;
    const loaded = readRegularFile(weeklyRoot, relativePath, `Evidence file ${logicalPath}`);
    if (isLiveFilesArtifact(entry.name)) requiredPortablePath(loaded.document.manifest_path, `${logicalPath}.manifest_path`);
    if (isClassificationArtifact(entry.name)) {
      requiredPortablePath(loaded.document.manifest_path, `${logicalPath}.manifest_path`);
      requiredPortablePath(loaded.document.live_files_path, `${logicalPath}.live_files_path`);
    }
    docs.push({ name: entry.name, relativePath: logicalPath, ...loaded, isDryRun: isDryRunArtifact(entry.name), isLive: isLiveFilesArtifact(entry.name), isSidecar: isClassificationArtifact(entry.name) });
  }
  assert(docs.length > 0, 'No JSON evidence files found in the manual deployments directory');
  return docs;
}

/**
 * Read and verify manual deployment evidence without writing receipts or workflow state.
 * A classification sidecar records an AI-assisted judgement with its limitations; the uploaded HTML is never
 * parsed to infer whether SEO main content changed.
 */
export function readManualDeploymentEvidence({
  projectRoot,
  weeklyRoot,
  manualDeploymentsDir = DEFAULT_MANUAL_DIR,
  now = new Date(),
} = {}) {
  const baseWeeklyRoot = weeklyRoot ?? (projectRoot ? path.join(projectRoot, DEFAULT_WEEKLY_ROOT) : path.join(defaultProjectRoot, DEFAULT_WEEKLY_ROOT));
  assert(typeof baseWeeklyRoot === 'string' && baseWeeklyRoot.length > 0, 'weeklyRoot is required');
  const resolvedWeeklyRoot = path.resolve(baseWeeklyRoot);
  assert(fs.existsSync(resolvedWeeklyRoot) && fs.lstatSync(resolvedWeeklyRoot).isDirectory(), 'weeklyRoot must be an existing directory');
  const manualDir = resolveManualDirectory(resolvedWeeklyRoot, manualDeploymentsDir);
  if (!manualDir) {
    return {
      schema_version: 1,
      contract: CONTRACT,
      status: 'passed',
      summary: { deployment_count: 0, page_candidate_count: 0, cooldown_eligible_count: 0, not_eligible_count: 0, blocked_unknown_count: 0 },
      date_candidates: [],
      evidence_summaries: [],
      evidence: [],
      empty_reason: 'manual_deployments_directory_missing',
    };
  }
  const docs = listEvidenceFiles(resolvedWeeklyRoot, manualDir, now);
  const production = docs.filter(doc => !doc.isDryRun && !doc.isLive && !doc.isSidecar);
  const liveDocs = docs.filter(doc => doc.isLive);
  const sidecarDocs = docs.filter(doc => doc.isSidecar);
  assert(production.length > 0, 'No non-dry-run deployment manifests were found');

  const allSidecarsByName = new Map(sidecarDocs.map(doc => [doc.name, doc]));
  assert(allSidecarsByName.size === sidecarDocs.length, 'Duplicate classification sidecar names');
  const consumedLive = new Set();
  const consumedSidecars = new Set();
  const evidence = [];
  const dateCandidates = [];

  for (const manifestFile of production) {
    const manifestLabel = `Manifest ${manifestFile.relativePath}`;
    const manifestInfo = validateManifest(manifestFile.document, manifestFile.bytes, manifestLabel, now);
    const manifestPath = manifestFile.relativePath;
    const matchingLive = liveDocs.filter(doc => doc.document.manifest_path === manifestPath);
    assert(matchingLive.length === 1, `${manifestLabel}: expected exactly one paired live-files record, found ${matchingLive.length}`);
    const liveFile = matchingLive[0];
    assert(!consumedLive.has(liveFile), `${manifestLabel}: live-files evidence was already paired with another manifest`);
    consumedLive.add(liveFile);
    const liveInfo = validateLiveFiles(liveFile.document, liveFile.bytes, `Live evidence ${liveFile.relativePath}`, manifestFile.document, manifestFile.bytes, manifestPath, manifestLabel, manifestInfo, now);

    const expectedSidecarName = sidecarNameFor(manifestFile.name);
    const sidecar = allSidecarsByName.get(expectedSidecarName) || null;
    if (sidecar) {
      assert(!consumedSidecars.has(sidecar), `${manifestLabel}: classification sidecar was already paired`);
      consumedSidecars.add(sidecar);
      const sidecarInfo = validateClassificationSidecar(
        sidecar.document,
        sidecar.bytes,
        sidecar.name,
        expectedSidecarName,
        manifestPath,
        manifestFile.sha256,
        liveFile.relativePath,
        liveFile.sha256,
        manifestInfo.htmlFiles,
        `Classification ${sidecar.relativePath}`,
        now,
      );
      assert(sidecarInfo.reviewed_ms >= liveInfo.generated_ms, `${sidecar.relativePath}: classification predates its live evidence`);
    }

    const evidenceId = `sha256:${manifestFile.sha256}`;
    evidence.push({
      evidence_id: evidenceId,
      manifest: { path: manifestPath, sha256: manifestFile.sha256, size_bytes: manifestFile.size_bytes, document: manifestFile.document },
      live_files: { path: liveFile.relativePath, sha256: liveFile.sha256, size_bytes: liveFile.size_bytes, document: liveFile.document },
      page_classification: sidecar
        ? { status: 'provided', path: sidecar.relativePath, sha256: sidecar.sha256, size_bytes: sidecar.size_bytes, document: sidecar.document }
        : { status: 'missing', expected_path: `${LOGICAL_WEEKLY_PREFIX}${path.relative(resolvedWeeklyRoot, path.join(manualDir, expectedSidecarName)).split(path.sep).join('/')}` },
    });

    const manifestFilesByPath = new Map(manifestFile.document.files.map(file => [file.relative_path, file]));
    const liveFilesByPath = new Map(liveFile.document.files.map(file => [file.path, file]));
    for (const htmlFile of manifestInfo.htmlFiles) {
      if (htmlFile.result !== 'uploaded') continue;
      const classification = sidecar
        ? sidecar.document.pages.find(page => page.path === htmlFile.relative_path)
        : null;
      const status = classification?.classification ?? 'unknown';
      const cooldownDecision = status === 'main_content_changed'
        ? 'eligible'
        : status === 'main_content_unchanged'
          ? 'not_eligible'
          : 'blocked_unknown';
      dateCandidates.push({
        page_url: pageUrl(htmlFile.relative_path),
        page_path: htmlFile.relative_path,
        candidate_at: manifestFile.document.completed_at,
        candidate_day_taipei: taipeiDate(manifestFile.document.completed_at),
        classification: {
          status,
          source: sidecar ? sidecar.relativePath : 'missing_sidecar',
          reviewer_kind: sidecar?.document.reviewer_kind ?? null,
          rationale: classification?.rationale ?? null,
        },
        cooldown_decision: cooldownDecision,
        classification_resolved: status !== 'unknown',
        evidence: {
          deployment_evidence_id: evidenceId,
          manifest_path: manifestFile.relativePath,
          manifest_sha256: manifestFile.sha256,
          manifest_status: manifestFile.document.status,
          manifest_dry_run: manifestFile.document.dry_run,
          manifest_target_host: manifestFile.document.target_host,
          manifest_completed_at: manifestFile.document.completed_at,
          manifest_summary: manifestFile.document.summary,
          live_files_path: liveFile.relativePath,
          live_files_sha256: liveFile.sha256,
          live_files_manifest_path: liveFile.document.manifest_path,
          live_files_manifest_sha256: liveFile.document.manifest_sha256,
          live_files_kind: liveFile.document.kind,
          live_files_checks: liveFile.document.checks,
          classification_sidecar: sidecar
            ? { status: 'provided', path: sidecar.relativePath, sha256: sidecar.sha256, reviewer_kind: sidecar.document.reviewer_kind }
            : { status: 'missing', expected_path: `${LOGICAL_WEEKLY_PREFIX}${path.relative(resolvedWeeklyRoot, path.join(manualDir, expectedSidecarName)).split(path.sep).join('/')}` },
          manifest_file: manifestFilesByPath.get(htmlFile.relative_path),
          live_file: liveFilesByPath.get(htmlFile.relative_path),
        },
      });
    }
  }

  assert(consumedLive.size === liveDocs.length, 'Unmatched live-files evidence exists');
  assert(consumedSidecars.size === sidecarDocs.length, 'Unmatched classification sidecar exists');
  assert(new Set(evidence.map(item => item.evidence_id)).size === evidence.length, 'Multiple manifests have identical byte hashes; evidence IDs are ambiguous');
  dateCandidates.sort((a, b) => a.page_url.localeCompare(b.page_url) || Date.parse(a.candidate_at) - Date.parse(b.candidate_at));
  const summary = {
    deployment_count: evidence.length,
    page_candidate_count: dateCandidates.length,
    cooldown_eligible_count: dateCandidates.filter(item => item.cooldown_decision === 'eligible').length,
    not_eligible_count: dateCandidates.filter(item => item.cooldown_decision === 'not_eligible').length,
    blocked_unknown_count: dateCandidates.filter(item => item.cooldown_decision === 'blocked_unknown').length,
  };
  return { schema_version: 1, contract: CONTRACT, status: 'passed', summary, date_candidates: dateCandidates, evidence_summaries: summarizeEvidence(evidence), evidence };
}

function parseArgs(args) {
  const options = {};
  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index];
    if (argument === '--help' || argument === '-h') return { help: true };
    assert(argument === '--project-root' || argument === '--weekly-root' || argument === '--manual-deployments-dir', `Unknown argument: ${argument}`);
    const value = args[index + 1];
    assert(value && !value.startsWith('--'), `${argument} requires a value`);
    options[argument === '--project-root' ? 'projectRoot' : argument === '--weekly-root' ? 'weeklyRoot' : 'manualDeploymentsDir'] = value;
    index += 1;
  }
  return options;
}

const modulePath = fileURLToPath(import.meta.url);
const defaultProjectRoot = path.resolve(path.dirname(modulePath), '..');

if (process.argv[1] && path.resolve(process.argv[1]) === modulePath) {
  try {
    const options = parseArgs(process.argv.slice(2));
    if (options.help) {
      process.stdout.write(`${JSON.stringify({
        contract: CONTRACT,
        usage: 'node scripts/manual-deploy-evidence-reader.mjs [--project-root PATH] [--weekly-root PATH] [--manual-deployments-dir PATH]',
        output: 'Compact candidate JSON on stdout; rejected evidence exits with code 1 and status=rejected.',
      }, null, 2)}\n`);
    } else {
      const result = readManualDeploymentEvidence({ projectRoot: options.projectRoot ?? defaultProjectRoot, weeklyRoot: options.weeklyRoot, manualDeploymentsDir: options.manualDeploymentsDir });
      const { evidence, ...compact } = result;
      process.stdout.write(`${JSON.stringify(compact, null, 2)}\n`);
    }
  } catch (error) {
    process.stdout.write(`${JSON.stringify({ schema_version: 1, contract: CONTRACT, status: 'rejected', error: error.message }, null, 2)}\n`);
    process.exitCode = 1;
  }
}
