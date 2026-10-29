import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';
import { evaluateRoundGate, FIXED_REQUIRED_VALIDATIONS } from './seo-geo-round-gate.mjs';

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(scriptDir, '..');
const htaPath = path.join(repoRoot, 'Weekly SOP', 'Weekly SOP Launcher.hta');
const root = 'C:\\fixture\\Weekly SOP';

function readWriterCommands(relativePath, variableName) {
  const source = fs.readFileSync(path.join(repoRoot, relativePath), 'utf8');
  const match = source.match(new RegExp(`\\$${variableName}\\s*=\\s*@\\(([\\s\\S]*?)\\)`));
  assert(match, `${relativePath} is missing its fixed validation command contract`);
  return [...match[1].matchAll(/'([^']+)'/g)].map((item) => item[1]).sort();
}

for (const [writer, variable] of [
  ['scripts/complete-seo-geo-round.ps1', 'requiredCommands'],
  ['scripts/write-seo-geo-validation-receipt.ps1', 'fixedRequiredValidations'],
]) {
  assert.deepEqual(readWriterCommands(writer, variable), [...FIXED_REQUIRED_VALIDATIONS].sort(), `${writer} and the shared UI gate have different required commands`);
}

function clone(value) {
  return value === undefined ? undefined : structuredClone(value);
}

function sha(byte) {
  return byte.repeat(64);
}

function extractFunction(source, name) {
  const marker = new RegExp(`\\bfunction\\s+${name}\\s*\\(`).exec(source);
  if (!marker) return null;

  let openParen = source.indexOf('(', marker.index);
  let parenDepth = 0;
  let quote = '';
  let escaped = false;
  for (let index = openParen; index < source.length; index += 1) {
    const char = source[index];
    if (quote) {
      if (escaped) escaped = false;
      else if (char === '\\') escaped = true;
      else if (char === quote) quote = '';
      continue;
    }
    if (char === '"' || char === "'" || char === '`') {
      quote = char;
      continue;
    }
    if (char === '(') parenDepth += 1;
    else if (char === ')') {
      parenDepth -= 1;
      if (parenDepth === 0) {
        openParen = index + 1;
        break;
      }
    }
  }

  const bodyStart = source.indexOf('{', openParen);
  assert(bodyStart >= 0, `HTA function body not found: ${name}`);
  let braceDepth = 0;
  let state = 'code';
  escaped = false;
  for (let index = bodyStart; index < source.length; index += 1) {
    const char = source[index];
    const next = source[index + 1];
    if (state === 'line-comment') {
      if (char === '\n') state = 'code';
      continue;
    }
    if (state === 'block-comment') {
      if (char === '*' && next === '/') {
        state = 'code';
        index += 1;
      }
      continue;
    }
    if (state === 'string') {
      if (escaped) escaped = false;
      else if (char === '\\') escaped = true;
      else if (char === quote) state = 'code';
      continue;
    }
    if (char === '/' && next === '/') {
      state = 'line-comment';
      index += 1;
      continue;
    }
    if (char === '/' && next === '*') {
      state = 'block-comment';
      index += 1;
      continue;
    }
    if (char === '"' || char === "'" || char === '`') {
      quote = char;
      state = 'string';
      continue;
    }
    if (char === '{') braceDepth += 1;
    else if (char === '}') {
      braceDepth -= 1;
      if (braceDepth === 0) return source.slice(marker.index, index + 1);
    }
  }
  throw new Error(`Unterminated HTA function: ${name}`);
}

function makeSnapshot(seed) {
  return {
    sha256: sha(seed[0]),
    manifest_sha256: sha(seed[1]),
    query_baseline: { sha256: sha(seed[2]) },
    page_baseline: { sha256: sha(seed[3]) },
  };
}

function makeFixture() {
  const actionIds = ['action-101', 'action-202'];
  const fingerprints = [sha('1'), sha('2')];
  const requiredValidations = [
    'node .agents/skills/curtain-online-seo-geo/scripts/keyword-owner-check.mjs',
    'npm.cmd run build',
    'npm.cmd run seo:check',
    'npm.cmd run seo:preflight',
  ];
  const registry = { path: 'config/target-registry.json', sha256: sha('3'), version: 2 };
  const snapshot = {
    '7d': makeSnapshot(['4', '5', '6', '7']),
    '28d': makeSnapshot(['8', '9', 'a', 'b']),
  };
  const roundActions = actionIds.map((action_id, index) => ({
    action_id,
    fingerprint: fingerprints[index],
  }));
  const state = {
    schema_version: 2,
    queue_id: 'queue-2026-10-29-001',
    cycle_key: '2026-10',
    status: 'active',
    active_round: 1,
    source_fingerprint: sha('c'),
    receipt_path: 'latest/seo-geo-validation-receipt.json',
    registry: clone(registry),
    snapshot: clone(snapshot),
    prompt_files: [{
      round: 1,
      action_ids: clone(actionIds),
      action_fingerprints: clone(fingerprints),
      required_validations: clone(requiredValidations),
    }],
    rounds: [{
      round: 1,
      action_ids: clone(actionIds),
      action_fingerprints: clone(fingerprints),
      required_validations: clone(requiredValidations),
    }],
  };
  const queue = {
    schema_version: 2,
    queue_id: state.queue_id,
    cycle_key: state.cycle_key,
    status: 'active',
    source_fingerprint: state.source_fingerprint,
    registry: clone(registry),
    snapshot: clone(snapshot),
    rounds: [{
      round: 1,
      action_ids: clone(actionIds),
      action_fingerprints: clone(fingerprints),
      required_validations: clone(requiredValidations),
      actions: clone(roundActions),
    }],
  };
  const receipt = {
    schema_version: 2,
    status: 'passed',
    result: 'implemented',
    queue_id: state.queue_id,
    cycle_key: state.cycle_key,
    round: 1,
    action_ids: clone(actionIds),
    action_fingerprints: actionIds.map((action_id, index) => ({ action_id, fingerprint: fingerprints[index] })),
    source_fingerprint_before: state.source_fingerprint,
    source_fingerprint_after: sha('d'),
    registry: clone(registry),
    snapshot: clone(snapshot),
    validation_results: requiredValidations.map((command) => ({ command, status: 'passed', exit_code: 0 })),
  };
  return { root, state, queue, receipt, round: 1 };
}

const cases = [];
function addCase(name, expected, change = (fixture) => fixture, { parity = true, strict = false } = {}) {
  cases.push({ name, expected, change, parity, strict });
}

addCase('valid implemented receipt', true);
addCase('valid no_change_verified receipt', true, (fixture) => {
  fixture.receipt.result = 'no_change_verified';
  fixture.receipt.source_fingerprint_after = fixture.receipt.source_fingerprint_before;
  return fixture;
});
addCase('missing receipt', false, (fixture) => { fixture.receipt = null; return fixture; });
addCase('wrong round', false, (fixture) => { fixture.receipt.round = 2; return fixture; });
addCase('wrong queue id', false, (fixture) => { fixture.receipt.queue_id = 'other-queue'; return fixture; });
addCase('wrong cycle key', false, (fixture) => { fixture.receipt.cycle_key = '2026-09'; return fixture; });
addCase('receipt action ids missing one action', false, (fixture) => { fixture.receipt.action_ids.pop(); return fixture; });
addCase('receipt action ids include an extra action', false, (fixture) => { fixture.receipt.action_ids.push('action-extra'); return fixture; });
addCase('receipt fingerprint differs', false, (fixture) => { fixture.receipt.action_fingerprints[0].fingerprint = sha('e'); return fixture; });
addCase('receipt fingerprint missing', false, (fixture) => { fixture.receipt.action_fingerprints[0].fingerprint = ''; return fixture; });
addCase('receipt path missing', false, (fixture) => { delete fixture.state.receipt_path; return fixture; });
addCase('receipt path points elsewhere', false, (fixture) => { fixture.state.receipt_path = 'latest/other-receipt.json'; return fixture; });
addCase('receipt path escapes the runtime root', false, (fixture) => { fixture.state.receipt_path = '../outside/seo-geo-validation-receipt.json'; return fixture; });
addCase('receipt source fingerprint before differs', false, (fixture) => { fixture.receipt.source_fingerprint_before = sha('e'); return fixture; });
addCase('receipt source fingerprint after missing', false, (fixture) => { delete fixture.receipt.source_fingerprint_after; return fixture; });
addCase('implemented receipt must change source fingerprint', false, (fixture) => {
  fixture.receipt.source_fingerprint_after = fixture.receipt.source_fingerprint_before;
  return fixture;
});
addCase('no_change_verified receipt must preserve source fingerprint', false, (fixture) => {
  fixture.receipt.result = 'no_change_verified';
  return fixture;
});
addCase('unknown receipt result', false, (fixture) => { fixture.receipt.result = 'skipped'; return fixture; });
addCase('receipt status is not passed', false, (fixture) => { fixture.receipt.status = 'failed'; return fixture; });
addCase('receipt registry path differs', false, (fixture) => { fixture.receipt.registry.path = 'config/other-registry.json'; return fixture; });
addCase('receipt registry sha differs', false, (fixture) => { fixture.receipt.registry.sha256 = sha('e'); return fixture; });
addCase('receipt registry version differs', false, (fixture) => { fixture.receipt.registry.version += 1; return fixture; });
addCase('receipt registry binding missing', false, (fixture) => { delete fixture.receipt.registry; return fixture; });

for (const window of ['7d', '28d']) {
  for (const [binding, field] of [
    ['sha256', 'input sha'],
    ['manifest_sha256', 'manifest sha'],
    ['query_baseline', 'query baseline sha'],
    ['page_baseline', 'page baseline sha'],
  ]) {
    addCase(`${window} receipt ${field} differs`, false, (fixture) => {
      if (binding === 'query_baseline' || binding === 'page_baseline') fixture.receipt.snapshot[window][binding].sha256 = sha('e');
      else fixture.receipt.snapshot[window][binding] = sha('e');
      return fixture;
    });
  }
}

addCase('queue and state queue ids differ', false, (fixture) => { fixture.queue.queue_id = 'other-queue'; return fixture; });
addCase('queue and state cycle keys differ', false, (fixture) => { fixture.queue.cycle_key = '2026-09'; return fixture; });
addCase('state and queue action ids differ', false, (fixture) => { fixture.queue.rounds[0].action_ids.pop(); return fixture; });
addCase('queue round and queue actions differ', false, (fixture) => { fixture.queue.rounds[0].actions.pop(); return fixture; });
addCase('queue and state source fingerprints differ', false, (fixture) => { fixture.queue.source_fingerprint = sha('e'); return fixture; });
addCase('queue registry binding differs from state', false, (fixture) => { fixture.queue.registry.sha256 = sha('e'); return fixture; });
addCase('queue snapshot binding differs from state', false, (fixture) => { fixture.queue.snapshot['28d'].page_baseline.sha256 = sha('e'); return fixture; });
addCase('state and prompt action ids differ', false, (fixture) => { fixture.state.prompt_files[0].action_ids.pop(); return fixture; });
addCase('state and prompt fingerprints differ', false, (fixture) => { fixture.state.prompt_files[0].action_fingerprints[0] = sha('e'); return fixture; });
addCase('state and queue required validation commands differ', false, (fixture) => { fixture.queue.rounds[0].required_validations.pop(); return fixture; });
addCase('required command absent from receipt results', false, (fixture) => { fixture.receipt.validation_results.pop(); return fixture; });
addCase('required command result failed', false, (fixture) => { fixture.receipt.validation_results[0].status = 'failed'; return fixture; });
addCase('required command exit code is nonzero', false, (fixture) => { fixture.receipt.validation_results[0].exit_code = 1; return fixture; });
addCase('required command name differs', false, (fixture) => { fixture.receipt.validation_results[0].command = 'npm.cmd run test'; return fixture; });
addCase('missing state registry binding', false, (fixture) => { delete fixture.state.registry; return fixture; });
addCase('missing state snapshot binding', false, (fixture) => { delete fixture.state.snapshot['7d']; return fixture; });
addCase('missing state source fingerprint', false, (fixture) => { fixture.state.source_fingerprint = ''; return fixture; });
addCase('missing state round action ids', false, (fixture) => { delete fixture.state.rounds[0].action_ids; return fixture; });
addCase('missing round fingerprints from all contract sources', false, (fixture) => {
  delete fixture.state.prompt_files[0].action_fingerprints;
  delete fixture.state.rounds[0].action_fingerprints;
  delete fixture.queue.rounds[0].action_fingerprints;
  delete fixture.queue.rounds[0].actions[0].fingerprint;
  delete fixture.queue.rounds[0].actions[1].fingerprint;
  return fixture;
});
addCase('queue missing', false, (fixture) => { fixture.queue = null; return fixture; });
addCase('prompt round is absent', false, (fixture) => { fixture.state.prompt_files = []; return fixture; }, { parity: false, strict: true });

// These cases deliberately require stricter fail-closed behavior than the old
// HTA gate: queue schema/status and the command set must match the executor's
// active schema-v2 contract exactly.
addCase('state status is not active', false, (fixture) => { fixture.state.status = 'observation_only'; return fixture; }, { parity: false, strict: true });
addCase('queue status is not active', false, (fixture) => { fixture.queue.status = 'completed'; return fixture; }, { parity: false, strict: true });
addCase('state schema version is not 2', false, (fixture) => { fixture.state.schema_version = 1; return fixture; }, { parity: false, strict: true });
addCase('queue schema version is not 2', false, (fixture) => { fixture.queue.schema_version = 1; return fixture; }, { parity: false, strict: true });
addCase('prompt round validation commands differ from fixed contract', false, (fixture) => {
  fixture.state.prompt_files[0].required_validations.pop();
  return fixture;
}, { parity: false, strict: true });
addCase('state and queue both omit required commands', false, (fixture) => {
  delete fixture.state.rounds[0].required_validations;
  delete fixture.queue.rounds[0].required_validations;
  return fixture;
}, { parity: false, strict: true });
addCase('all round sources omit required validation commands', false, (fixture) => {
  delete fixture.state.prompt_files[0].required_validations;
  delete fixture.state.rounds[0].required_validations;
  delete fixture.queue.rounds[0].required_validations;
  fixture.receipt.validation_results = [];
  return fixture;
}, { parity: false, strict: true });
addCase('receipt has an extra validation command', false, (fixture) => {
  fixture.receipt.validation_results.push({ command: 'npm.cmd run test', status: 'passed', exit_code: 0 });
  return fixture;
}, { parity: false, strict: true });
addCase('receipt includes a failed validation command', false, (fixture) => {
  fixture.receipt.validation_results[0].status = 'failed';
  return fixture;
}, { parity: false, strict: true });

function makeLegacyEvaluator(source) {
  const names = [
    'resolveManifestPath', 'asArray', 'uniqueSortedStrings', 'sameStringSet', 'findRoundItem',
    'appendCommandValues', 'normalizeActionFingerprints', 'getActionFingerprintValue',
    'sameActionFingerprints', 'normalizeRegistryBinding', 'sameRegistryBinding',
    'normalizeSnapshotWindow', 'sameSnapshotWindow', 'sameSnapshotBinding', 'getRoundContract', 'getReceiptGate',
  ];
  const extracted = names.map((name) => extractFunction(source, name));
  if (extracted.some((fn) => !fn)) return null;
  return (fixture) => {
    const runtimeRoot = fixture.root;
    const readerPath = path.win32.resolve(fixture.root, 'latest', 'seo-geo-validation-receipt.json');
    const context = {
      ActiveXObject: function ActiveXObject() {
        return { GetAbsolutePathName: (value) => path.win32.resolve(String(value).replace(/\//g, '\\')) };
      },
      readJsonIfExists: (value) => path.win32.resolve(String(value).replace(/\//g, '\\')).toLowerCase() === readerPath.toLowerCase()
        ? clone(fixture.receipt)
        : null,
    };
    vm.createContext(context);
    for (const fn of extracted) vm.runInContext(fn, context, { filename: 'Weekly SOP Launcher.hta' });
    return context.getReceiptGate(runtimeRoot, clone(fixture.state), clone(fixture.queue), fixture.round);
  };
}

let legacyEvaluate = null;
if (fs.existsSync(htaPath)) {
  const hta = fs.readFileSync(htaPath, 'utf8');
  if (/\bfunction\s+getReceiptGate\s*\(/.test(hta)) {
    legacyEvaluate = makeLegacyEvaluator(hta);
    if (!legacyEvaluate) throw new Error('Legacy getReceiptGate exists but a required helper could not be extracted.');
  }
}

let parityCount = 0;
let strictCount = 0;
for (const testCase of cases) {
  const fixture = testCase.change(makeFixture());
  const result = evaluateRoundGate({
    root: fixture.root,
    state: fixture.state,
    queue: fixture.queue,
    receipt: fixture.receipt,
    round: fixture.round,
  });
  assert.equal(typeof result?.passed, 'boolean', `${testCase.name}: gate must return a boolean passed field`);
  assert.equal(result.passed, testCase.expected, `${testCase.name}: expected passed=${testCase.expected}, got ${result.passed} (${result.reason || 'no reason'})`);

  if (testCase.strict) {
    strictCount += 1;
    assert.equal(result.passed, false, `${testCase.name}: stricter fail-closed case must be rejected`);
  }
  if (legacyEvaluate && testCase.parity) {
    const legacy = legacyEvaluate(fixture);
    assert.equal(result.passed, legacy.passed, `${testCase.name}: migrated gate differs from legacy HTA passed result`);
    parityCount += 1;
  }
}

console.log(`PASS SEO/GEO Round gate: ${cases.length} fixture cases (${strictCount} stricter fail-closed assertions)`);
if (legacyEvaluate) console.log(`PASS legacy HTA parity: ${parityCount} common-input cases matched`);
else console.log('SKIP legacy HTA parity: old getReceiptGate is absent; fixed expected-result cases still ran');
