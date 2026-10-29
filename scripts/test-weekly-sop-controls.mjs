import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(scriptDir, '..');
const htaPath = path.join(repoRoot, 'Weekly SOP', 'Weekly SOP Launcher.hta');
const hta = fs.readFileSync(htaPath, 'utf8');

function clone(value) {
  return value === undefined ? undefined : structuredClone(value);
}

function extractFunction(source, name) {
  const marker = new RegExp(`\\bfunction\\s+${name}\\s*\\(`).exec(source);
  assert(marker, `HTA function not found: ${name}`);

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

const extractedFunctions = [
  'actionIdToType',
  'configureSmartSeoGeoControls',
  'updateWorkflowControls',
  'executeCurrentSeoGeoNextStep',
  'runSeoGeoAutoDeploy',
].map((name) => extractFunction(hta, name));
const snapshotAndPanelFunctions = [
  'getQueueSnapshot',
  'refreshQueueStatus',
  'htmlEscape',
  'getRoundState',
  'localizeLifecycleStatus',
  'summarizeTargets',
].map((name) => extractFunction(hta, name));

const root = 'C:\\fixture\\Weekly SOP';

function makeProjection({ state, id, enabled, reason, consistent = true, label }) {
  const actionLabel = label || `Action ${id}`;
  const primaryAction = { id, enabled, label: actionLabel, reason };
  const actions = {
    FETCH_GSC: { enabled: true, label: 'Fetch GSC', reason: 'fetch reason' },
    OPEN_PLAN: { enabled: true, label: 'Open plan', reason: 'open reason' },
    [id]: { enabled, label: actionLabel, reason },
  };
  return { consistent, state, primary_action: primaryAction, actions };
}

function makeQueue({
  state = 'active',
  consistent = true,
  isObservation = false,
  isLocalValidated = false,
  isAwaitingImplemented = false,
  isCopiedPending = false,
  lifecycleStatus = state,
  receiptPassed = false,
  receiptReason = 'validation receipt 尚未建立。',
} = {}) {
  return {
    exists: true,
    isStale: false,
    projection: { consistency: { valid: consistent } },
    isObservation,
    isLocalValidated,
    isAwaitingImplemented,
    isCopiedPending,
    lifecycleStatus,
    activeRound: 1,
    totalRounds: 2,
    queue: { optional_opportunities: [] },
    provenance: { reasons: [] },
    receiptGate: { passed: receiptPassed, reason: receiptReason },
    state: { queue_id: 'fixture-queue', cycle_key: 'fixture-cycle' },
    queueId: 'fixture-queue',
  };
}

function createHarness({ queue, projections = [], singlePageReviews = [], confirmResult = false }) {
  const state = {
    buttons: new Map(),
    panels: [],
    statusMessages: [],
    statusDetails: [],
    dispatches: [],
    projectionReads: 0,
    refreshes: 0,
    queueRefreshes: 0,
    confirms: [],
    shellRuns: [],
    busyStates: [],
  };
  const fso = {
    FileExists: () => true,
    GetParentFolderName: () => 'C:\\fixture',
  };
  const shell = {
    Run: (...args) => {
      state.shellRuns.push(args);
      return 0;
    },
  };
  const projectionReader = () => {
    const index = Math.min(state.projectionReads, projections.length - 1);
    state.projectionReads += 1;
    return projections[index] || null;
  };
  const sandbox = {
    isUiBusy: false,
    currentSeoGeoNextAction: null,
    getRootFolder: () => root,
    getSmartReportDecision: () => ({ action: 'none', title: 'fixture report state' }),
    setButtonState: (id, disabled, label, reason) => state.buttons.set(id, { disabled, label, reason }),
    setStatusSummary: (message, type) => state.statusMessages.push({ message, type }),
    renderWorkflowPanel: (type, title, detail) => state.panels.push({ type, title, detail }),
    getSeoGeoUiProjection: projectionReader,
    getLifecycleNextInspection: () => ({ ready: false, label: 'lifecycle unavailable', reason: 'fixture lifecycle gate' }),
    getDeploymentManifestGate: () => ({ passed: false, reason: 'fixture deployment manifest gate' }),
    getQueueSnapshot: () => queue,
    commandExists: () => true,
    getWindowFreshness: (_root, window) => ({
      mode: 'ok',
      decisionReady: true,
      snapshotFamilyId: 'fixture-snapshot',
      endDate: '2026-10-20',
      gates: `${window} passed`,
    }),
    getTargetRegistry: () => ({ mode: 'ok', text: 'fixture registry' }),
    getLatestImportStatus: () => ({ isDuplicate: false }),
    isFreshStatus: (value) => Boolean(value && value.mode === 'ok'),
    asArray: (value) => value == null ? [] : (Array.isArray(value) ? value : [value]),
    ActiveXObject: function ActiveXObject() { return fso; },
    getElementById: () => null,
    confirm: (message) => {
      state.confirms.push(message);
      return confirmResult;
    },
    setButtonsBusy: (busy) => state.busyStates.push(busy),
    setStatusDetails: (message) => state.statusDetails.push(message),
    readTextIfExists: () => 'fixture auto-deploy log',
    refreshQueueStatus: () => { state.queueRefreshes += 1; },
    singlePageReviews,
    getSinglePageReviewCount: () => singlePageReviews.length,
    updateWorkflowControls: () => { state.refreshes += 1; },
  };

  for (const name of [
    'runSeoGeoActionPlan', 'openLatestSeoGeoActionPlan', 'copyLatestSeoGeoAiPrompt',
    'advanceSeoGeoRound', 'approveSinglePageReview', 'runSeoGeoDeployment',
    'runSeoGeoAutoDeploy', 'runSeoGeoLiveVerification', 'invokeLifecycleNext',
  ]) {
    sandbox[name] = (...args) => state.dispatches.push({ name, args });
  }

  vm.createContext(sandbox);
  for (const source of extractedFunctions) vm.runInContext(source, sandbox, { filename: 'Weekly SOP Launcher.hta' });
  sandbox.ActiveXObject = function ActiveXObject(programId) {
    if (programId === 'WScript.Shell') return shell;
    return fso;
  };
  return { sandbox, state };
}

function assertButton(harness, id, expected) {
  const actual = harness.state.buttons.get(id);
  assert(actual, `Button was not configured: ${id}`);
  assert.equal(actual.disabled, expected.disabled, `${id} disabled state`);
  if (expected.label !== undefined) assert.equal(actual.label, expected.label, `${id} label`);
  if (expected.reason !== undefined) assert.equal(actual.reason, expected.reason, `${id} status hint`);
  return actual;
}

function assertPrimaryProjection(harness, projection) {
  const current = harness.sandbox.currentSeoGeoNextAction;
  const gated = projection.consistent !== true;
  const expectedId = gated ? 'NONE' : projection.primary_action.id;
  assert.equal(current.actionId, expectedId, 'main action id must follow UI projection consistency');
  assert.equal(current.type, expectedId === 'NONE' ? 'none' : harness.sandbox.actionIdToType(expectedId));
  assert.equal(current.enabled, !gated && projection.primary_action.enabled === true, 'main action enabled state must follow UI projection');
  assertButton(harness, 'btnSeoGeoNextSmart', {
    disabled: gated || projection.primary_action.enabled !== true,
    label: gated ? '流程資料讀取失敗' : projection.primary_action.label,
    reason: projection.primary_action.reason,
  });
}

function runConfigureCase(name, queue, projection) {
  const harness = createHarness({ queue, projections: [projection] });
  harness.sandbox.configureSmartSeoGeoControls(root, true, true, queue);
  assertPrimaryProjection(harness, projection);
  return harness;
}

const actionTypes = {
  GENERATE_PLAN: 'generate_plan',
  OPEN_PLAN: 'open_plan',
  COPY_ROUND_PROMPT: 'copy_round',
  ADVANCE_ROUND: 'advance_round',
  APPROVE_SINGLE_PAGE: 'approve_single_page',
  DEPLOY_DRY_RUN: 'dry_run',
  DEPLOY: 'deploy',
  AUTO_DEPLOY: 'auto_deploy',
  LIVE_VERIFY: 'live_verify',
  ADVANCE_LIFECYCLE: 'lifecycle',
  NONE: 'none',
};
for (const [actionId, expectedType] of Object.entries(actionTypes)) {
  const harness = createHarness({ queue: makeQueue(), projections: [] });
  assert.equal(harness.sandbox.actionIdToType(actionId), expectedType, `actionIdToType(${actionId})`);
}

const observationProjection = makeProjection({ state: 'observation_only', id: 'GENERATE_PLAN', enabled: true, reason: '需要 decision-ready GSC snapshot。' });
runConfigureCase('observation_only', makeQueue({ state: 'observation_only', isObservation: true }), observationProjection);

const activeWaitingProjection = makeProjection({ state: 'active', id: 'COPY_ROUND_PROMPT', enabled: true, reason: 'validation receipt 尚未建立。' });
runConfigureCase('active waiting receipt', makeQueue({ state: 'active', isCopiedPending: true }), activeWaitingProjection);

const activePassedProjection = makeProjection({ state: 'active', id: 'ADVANCE_ROUND', enabled: true, reason: 'validation receipt 已通過。' });
runConfigureCase('active passed receipt', makeQueue({ state: 'active', receiptPassed: true }), activePassedProjection);

const localValidatedProjection = makeProjection({ state: 'local_validated', id: 'AUTO_DEPLOY', enabled: false, reason: '缺少 FTP_USER 或 FTP_PASS。' });
runConfigureCase('local_validated', makeQueue({ state: 'local_validated', isLocalValidated: true }), localValidatedProjection);

const deployedProjection = makeProjection({ state: 'deployed', id: 'LIVE_VERIFY', enabled: true, reason: 'deployment 已記錄；尚缺 live verification。' });
runConfigureCase('deployed', makeQueue({ state: 'deployed', isLocalValidated: true }), deployedProjection);

const inconsistentProjection = makeProjection({ state: 'inconsistent', id: 'NONE', enabled: false, reason: 'Workflow consistency 未通過：plan_queue_identity_mismatch。', consistent: false });
runConfigureCase('workflow inconsistent', makeQueue({ state: 'local_validated', consistent: false, isLocalValidated: true }), inconsistentProjection);

const projectionError = makeProjection({ state: 'projection_error', id: 'NONE', enabled: false, reason: 'UI projection 讀取失敗：fixture error。', consistent: false });
runConfigureCase('projection error', makeQueue({ state: 'local_validated', consistent: false, isLocalValidated: true }), projectionError);

function runUpdateCase(queue, projection) {
  const harness = createHarness({ queue, projections: [projection] });
  harness.sandbox.updateWorkflowControls();
  return harness;
}

let harness = runUpdateCase(makeQueue({ state: 'observation_only', isObservation: true }), observationProjection);
assertButton(harness, 'btnSeoGeoNextSmart', { disabled: false, label: observationProjection.primary_action.label });
assertButton(harness, 'btnCopySeoGeoAiPrompt', { disabled: true });
assertButton(harness, 'btnAdvanceSeoGeoRound', { disabled: true });
assertButton(harness, 'btnSeoGeoDeployDryRun', { disabled: true });
assertButton(harness, 'btnSeoGeoDeploy', { disabled: true });
assertButton(harness, 'btnSeoGeoLiveVerify', { disabled: true });
assert.equal(harness.state.panels.at(-1).title, '流程狀態：observation_only（僅觀察）');
assert.equal(harness.state.panels.at(-1).type, 'warn');

harness = runUpdateCase(makeQueue({ state: 'active', isCopiedPending: true }), activeWaitingProjection);
assertButton(harness, 'btnSeoGeoNextSmart', { disabled: false, label: activeWaitingProjection.primary_action.label });
assertButton(harness, 'btnCopySeoGeoAiPrompt', { disabled: false });
assertButton(harness, 'btnAdvanceSeoGeoRound', { disabled: true });
assert.equal(harness.state.panels.at(-1).title, '流程狀態：Round 1/2 已複製，等待 receipt');
assert.equal(harness.state.panels.at(-1).type, 'warn');
assert.match(harness.state.panels.at(-1).detail, /validation receipt 尚未建立/);

harness = runUpdateCase(makeQueue({ state: 'active', receiptPassed: true }), activePassedProjection);
assertButton(harness, 'btnSeoGeoNextSmart', { disabled: false, label: activePassedProjection.primary_action.label });
assertButton(harness, 'btnAdvanceSeoGeoRound', { disabled: false });
assert.equal(harness.state.panels.at(-1).title, '流程狀態：Round 1/2 驗證通過');
assert.equal(harness.state.panels.at(-1).type, 'ok');

harness = runUpdateCase(makeQueue({ state: 'local_validated', isLocalValidated: true }), localValidatedProjection);
assertButton(harness, 'btnSeoGeoNextSmart', { disabled: true, label: localValidatedProjection.primary_action.label });
assertButton(harness, 'btnSeoGeoDeployDryRun', { disabled: false });
assertButton(harness, 'btnSeoGeoDeploy', { disabled: false });
assertButton(harness, 'btnSeoGeoLiveVerify', { disabled: true });
assert.equal(harness.state.panels.at(-1).title, '流程狀態：local_validated');
assert.equal(harness.state.panels.at(-1).type, 'warn');
assert.match(harness.state.panels.at(-1).detail, /缺少 FTP_USER 或 FTP_PASS/);

harness = runUpdateCase(makeQueue({ state: 'deployed', isLocalValidated: true }), deployedProjection);
assertButton(harness, 'btnSeoGeoNextSmart', { disabled: false, label: deployedProjection.primary_action.label });
assertButton(harness, 'btnSeoGeoDeployDryRun', { disabled: true });
assertButton(harness, 'btnSeoGeoDeploy', { disabled: true });
assertButton(harness, 'btnSeoGeoLiveVerify', { disabled: false });
assert.equal(harness.state.panels.at(-1).title, '流程狀態：deployed');
assert.equal(harness.state.panels.at(-1).type, 'ok');

harness = runUpdateCase(makeQueue({ state: 'local_validated', consistent: false, isLocalValidated: true }), inconsistentProjection);
assertButton(harness, 'btnSeoGeoNextSmart', { disabled: true, label: '流程資料讀取失敗' });
assertButton(harness, 'btnSeoGeoDeployDryRun', { disabled: true });
assertButton(harness, 'btnSeoGeoDeploy', { disabled: true });
assertButton(harness, 'btnSeoGeoLiveVerify', { disabled: true });
assert.equal(harness.state.panels.at(-1).title, '流程狀態：local_validated');
assert.equal(harness.state.panels.at(-1).type, 'warn');
assert.match(harness.state.panels.at(-1).detail, /plan_queue_identity_mismatch/);

// A UI projection read failure must stop the primary action. The legacy secondary
// deployment controls remain independently gated by the effective workflow check.
harness = runUpdateCase(makeQueue({ state: 'local_validated', isLocalValidated: true }), projectionError);
assertButton(harness, 'btnSeoGeoNextSmart', { disabled: true, label: '流程資料讀取失敗' });
assertButton(harness, 'btnSeoGeoDeployDryRun', { disabled: false });
assertButton(harness, 'btnSeoGeoDeploy', { disabled: false });
assert.match(harness.state.panels.at(-1).detail, /UI projection 讀取失敗/);

const freshEnabled = makeProjection({ state: 'local_validated', id: 'AUTO_DEPLOY', enabled: true, reason: '部署 preflight 通過。' });
const freshDisabled = makeProjection({ state: 'local_validated', id: 'AUTO_DEPLOY', enabled: false, reason: '點擊前狀態改變，AUTO_DEPLOY 已停用。' });
harness = createHarness({
  queue: makeQueue({ state: 'local_validated', isLocalValidated: true }),
  projections: [freshEnabled, freshDisabled],
});
harness.sandbox.configureSmartSeoGeoControls(root, true, true, makeQueue({ state: 'local_validated', isLocalValidated: true }));
assertButton(harness, 'btnSeoGeoNextSmart', { disabled: false, label: freshEnabled.primary_action.label });
harness.sandbox.updateWorkflowControls = () => { harness.state.refreshes += 1; };
harness.sandbox.executeCurrentSeoGeoNextStep();
assert.equal(harness.state.dispatches.length, 0, 'stale enabled action must not dispatch after fresh projection disables it');
assert.equal(harness.state.refreshes, 1, 'blocked stale click should refresh workflow controls');
assert.match(harness.state.statusMessages.at(-1).message, /點擊前狀態改變，AUTO_DEPLOY 已停用/);

function runAutoDeployCase(projection, confirmResult) {
  const result = createHarness({
    queue: makeQueue({ state: 'local_validated', isLocalValidated: true }),
    projections: [projection],
    confirmResult,
  });
  result.sandbox.updateWorkflowControls = () => { result.state.refreshes += 1; };
  result.sandbox.runSeoGeoAutoDeploy();
  return result;
}

const blockedDeployProjection = makeProjection({
  state: 'local_validated',
  id: 'AUTO_DEPLOY',
  enabled: false,
  reason: 'deploy preflight 未通過。',
});
harness = runAutoDeployCase(blockedDeployProjection, true);
assert.equal(harness.state.confirms.length, 0, 'projection gate failure must stop before prompting');
assert.equal(harness.state.shellRuns.length, 0, 'projection gate failure must not run the shell');
assert.match(harness.state.statusMessages.at(-1).message, /deploy preflight 未通過/);

const readyDeployProjection = makeProjection({
  state: 'local_validated',
  id: 'AUTO_DEPLOY',
  enabled: true,
  reason: 'deploy preflight 通過。',
});
harness = runAutoDeployCase(readyDeployProjection, false);
assert.equal(harness.state.confirms.length, 1, 'ready auto-deploy must ask for confirmation');
assert.match(harness.state.confirms[0], /確認開始正式上傳/);
assert.equal(harness.state.shellRuns.length, 0, 'cancelling confirmation must not run the shell');
assert.equal(harness.state.busyStates.includes(true), false, 'cancelled deploy must not enter busy state');

harness = runAutoDeployCase(readyDeployProjection, true);
assert.equal(harness.state.confirms.length, 1, 'confirmed auto-deploy must ask once');
assert.equal(harness.state.shellRuns.length, 1, 'confirmed and gated auto-deploy must run once');
assert.match(harness.state.shellRuns[0][0], /-Mode Execute/);
assert.equal(harness.state.shellRuns[0][1], 1);
assert.equal(harness.state.shellRuns[0][2], true);
assert.deepEqual(harness.state.busyStates, [true, false]);
assert.equal(harness.state.statusMessages.at(-1).type, 'success');
assert.equal(harness.state.queueRefreshes, 1);

function makeQueueState(overrides = {}) {
  return {
    queue_id: 'fixture-queue',
    cycle_key: 'fixture-cycle',
    status: 'active',
    generated_at: '2026-10-29T00:00:00Z',
    active_round: 1,
    total_rounds: 2,
    completed_rounds: [],
    copied_rounds: [1],
    prompt_files: [{ round: 1, targetCount: 1, targets: ['https://example.test/page'] }],
    ...overrides,
  };
}

function makeQueueDocument(overrides = {}) {
  return {
    queue_id: 'fixture-queue',
    cycle_key: 'fixture-cycle',
    rounds: [{ round: 1, action_ids: ['action-1'] }],
    technical_tasks: [],
    optional_opportunities: [],
    ...overrides,
  };
}

function makeBoundUiProjection(state, {
  passed = false,
  reason = 'validation receipt 尚未建立。',
  identity = {},
  round,
  activeRound,
  stateSnapshot = state,
  queueSnapshot = makeQueueDocument(),
  trustReasons,
  consistent = true,
} = {}) {
  const primaryId = passed ? 'ADVANCE_ROUND' : 'COPY_ROUND_PROMPT';
  const primary = {
    id: consistent ? primaryId : 'NONE',
    enabled: consistent,
    label: consistent ? (passed ? '驗證通過並前進' : '複製本輪 AI 工作指令') : '流程資料讀取失敗',
    reason: consistent ? (passed ? 'validation receipt 已通過。' : reason) : reason,
  };
  return {
    consistent,
    state: state.status,
    primary_action: primary,
    actions: {
      FETCH_GSC: { enabled: true, label: '更新最新 GSC 資料', reason: 'fetch reason' },
      OPEN_PLAN: { enabled: true, label: '查看目前 SEO/GEO 優化報表', reason: 'open reason' },
      [primary.id]: primary,
    },
    identity: {
      queue_id: identity.queue_id || state.queue_id,
      cycle_key: identity.cycle_key || state.cycle_key,
    },
    panels: {
      data_trust: { reasons: typeof trustReasons === 'undefined' ? (consistent ? [] : [reason]) : trustReasons },
      queue: {
        active_round: typeof activeRound === 'undefined' ? state.active_round : activeRound,
        total_rounds: state.total_rounds,
        is_observation: stateSnapshot.status === 'observation_only',
        is_local_validated: ['awaiting_implemented_receipt', 'implemented', 'local_validated', 'deployed', 'live_verified', 'observing_7d', 'reviewed_28d', 'completed'].includes(stateSnapshot.status),
        is_awaiting_implemented: stateSnapshot.status === 'awaiting_implemented_receipt',
        is_copied_pending: (stateSnapshot.copied_rounds || []).includes(stateSnapshot.active_round) && !(stateSnapshot.completed_rounds || []).includes(stateSnapshot.active_round),
        receipt_gate: { passed, reason, round: typeof round === 'undefined' ? state.active_round : round },
        state_snapshot: clone(stateSnapshot),
        queue_snapshot: clone(queueSnapshot),
      },
    },
  };
}

function createSnapshotHarness({
  stateDoc = makeQueueState(),
  queueDoc = makeQueueDocument(),
  provenance = { stale: false, status: 'current', reasons: [] },
  effectiveProjection = { consistency: { valid: true, reasons: [] }, effective: { status: 'active' } },
  uiProjection = null,
} = {}) {
  const elements = new Map(['queueStatusPanel', 'queueStatusBody', 'queueStatusSummary', 'queueStatusBadge']
    .map((id) => [id, { id, className: '', innerText: '', innerHTML: '' }]));
  const state = {
    buttons: new Map(),
    workflowPanels: [],
    uiProjectionReads: 0,
    queueReads: 0,
    snapshotReads: 0,
  };
  const fso = {
    FileExists: () => true,
    FolderExists: () => true,
    GetParentFolderName: () => 'C:\\fixture',
  };
  const jsonReader = (filePath) => {
    state.snapshotReads += 1;
    if (String(filePath).endsWith('seo-geo-action-queue-state.json')) return clone(stateDoc);
    if (String(filePath).endsWith('seo-geo-action-queue.json')) {
      state.queueReads += 1;
      return clone(queueDoc);
    }
    return null;
  };
  const sandbox = {
    isUiBusy: false,
    currentSeoGeoNextAction: null,
    document: { getElementById: (id) => elements.get(id) || null },
    getRootFolder: () => root,
    getSmartReportDecision: () => ({ action: 'none', title: 'fixture report state' }),
    setButtonState: (id, disabled, label, reason) => state.buttons.set(id, { disabled, label, reason }),
    renderWorkflowPanel: (type, title, detail) => state.workflowPanels.push({ type, title, detail }),
    commandExists: () => true,
    getWindowFreshness: (_root, window) => ({
      mode: 'ok',
      decisionReady: true,
      snapshotFamilyId: 'fixture-snapshot',
      endDate: '2026-10-20',
      gates: `${window} passed`,
    }),
    getTargetRegistry: () => ({ mode: 'ok', text: 'fixture registry' }),
    getLatestImportStatus: () => ({ isDuplicate: false }),
    isFreshStatus: (value) => Boolean(value && value.mode === 'ok'),
    asArray: (value) => value == null ? [] : (Array.isArray(value) ? value : [value]),
    arrayContains: (values, target) => (values || []).some((value) => Number(value) === Number(target)),
    readJsonIfExists: jsonReader,
    readTextIfExists: () => 'fixture action plan log',
    getQueueProvenance: () => clone(provenance),
    getEffectiveWorkflowProjection: () => clone(effectiveProjection),
    getSeoGeoUiProjection: () => {
      state.uiProjectionReads += 1;
      return clone(uiProjection);
    },
    ActiveXObject: function ActiveXObject() { return fso; },
  };
  vm.createContext(sandbox);
  for (const source of extractedFunctions) vm.runInContext(source, sandbox, { filename: 'Weekly SOP Launcher.hta' });
  for (const source of snapshotAndPanelFunctions) vm.runInContext(source, sandbox, { filename: 'Weekly SOP Launcher.hta' });
  sandbox.readJsonIfExists = jsonReader;
  sandbox.getQueueProvenance = () => clone(provenance);
  sandbox.getEffectiveWorkflowProjection = () => clone(effectiveProjection);
  sandbox.getSeoGeoUiProjection = () => clone(uiProjection);
  sandbox.asArray = (value) => value == null ? [] : (Array.isArray(value) ? value : [value]);
  sandbox.arrayContains = (values, target) => (values || []).some((value) => Number(value) === Number(target));
  sandbox.readTextIfExists = () => 'fixture action plan log';
  sandbox.setButtonState = (id, disabled, label, reason) => state.buttons.set(id, { disabled, label, reason });
  sandbox.renderWorkflowPanel = (type, title, detail) => state.workflowPanels.push({ type, title, detail });
  sandbox.ActiveXObject = function ActiveXObject() { return fso; };
  return { sandbox, state, elements };
}

function runSnapshotPanelCase(name, options, { expectedStale, expectedGate, expectedPrimary, expectedPanelClass, panelText } = {}) {
  const stateDoc = Object.prototype.hasOwnProperty.call(options, 'stateDoc') ? options.stateDoc : makeQueueState();
  const uiProjection = Object.prototype.hasOwnProperty.call(options, 'uiProjection')
    ? options.uiProjection
    : makeBoundUiProjection(stateDoc);
  const harness = createSnapshotHarness({ ...options, uiProjection });
  const snapshot = harness.sandbox.getQueueSnapshot(root);
  assert.equal(snapshot.exists, Boolean(stateDoc), `${name}: snapshot exists`);
  if (typeof expectedStale === 'boolean') assert.equal(snapshot.isStale, expectedStale, `${name}: snapshot stale flag: ${JSON.stringify({ inputUiProjection: uiProjection, provenance: snapshot.provenance, projection: snapshot.projection, uiProjection: snapshot.uiProjection, receiptGate: snapshot.receiptGate })}`);
  if (typeof expectedGate === 'boolean') assert.equal(snapshot.receiptGate.passed, expectedGate, `${name}: snapshot receipt gate`);
  if (!snapshot.isStale && stateDoc) {
    assert.deepEqual(snapshot.state, uiProjection.panels.queue.state_snapshot, `${name}: snapshot state comes from the bound UI projection`);
    assert.deepEqual(snapshot.queue, uiProjection.panels.queue.queue_snapshot, `${name}: snapshot queue comes from the same UI projection`);
    assert.equal(harness.state.queueReads, 0, `${name}: current projection must avoid a second queue-file read`);
  }

  harness.sandbox.updateWorkflowControls();
  harness.sandbox.refreshQueueStatus();

  if (expectedPrimary) {
    assert.equal(harness.state.buttons.get('btnSeoGeoNextSmart')?.disabled, !expectedPrimary.enabled, `${name}: main button enabled state; buttons=${JSON.stringify([...harness.state.buttons.entries()])}; action=${JSON.stringify(harness.sandbox.currentSeoGeoNextAction)}; workflowPanels=${JSON.stringify(harness.state.workflowPanels)}`);
    assert.equal(harness.sandbox.currentSeoGeoNextAction.actionId, expectedPrimary.id, `${name}: main action id`);
  }
  if (expectedGate !== undefined && stateDoc) {
    assert.equal(harness.state.buttons.get('btnAdvanceSeoGeoRound')?.disabled, !expectedGate || expectedStale === true, `${name}: advance button follows snapshot gate and stale state`);
  }
  if (expectedPanelClass) assert.equal(harness.elements.get('queueStatusPanel').className, expectedPanelClass, `${name}: queue panel class`);
  if (panelText) assert.match(harness.elements.get('queueStatusSummary').innerText, panelText, `${name}: queue panel summary`);
  return harness;
}

const waitingGateReason = '必要驗證未通過：npm.cmd run build';
const pendingFileState = makeQueueState({ generated_at: 'file-state-generated-at' });
const pendingProjectionState = { ...pendingFileState, generated_at: 'projection-state-generated-at' };
const pendingFileQueue = makeQueueDocument({ technical_tasks: [{ priority: 2, type: 'audit', title: 'file-only queue task' }] });
const pendingProjectionQueue = makeQueueDocument({ technical_tasks: [{ priority: 1, type: 'audit', title: 'projection-only queue task' }] });
let integrated = runSnapshotPanelCase('active receipt pending', {
  stateDoc: pendingFileState,
  queueDoc: pendingFileQueue,
  uiProjection: makeBoundUiProjection(pendingFileState, {
    passed: false,
    reason: waitingGateReason,
    stateSnapshot: pendingProjectionState,
    queueSnapshot: pendingProjectionQueue,
  }),
}, {
  expectedStale: false,
  expectedGate: false,
  expectedPrimary: { id: 'COPY_ROUND_PROMPT', enabled: true },
  expectedPanelClass: 'queue-panel',
  panelText: /必要驗證未通過/,
});
assert.equal(integrated.state.buttons.get('btnAdvanceSeoGeoRound').disabled, true, 'pending receipt disables direct Advance');
assert.equal(integrated.state.buttons.get('btnCopySeoGeoAiPrompt').disabled, false, 'pending receipt permits copying the current Round');
assert.match(integrated.elements.get('queueStatusBody').innerHTML, /projection-state-generated-at/, 'panel state must come from the same UI projection as the gate');
assert.doesNotMatch(integrated.elements.get('queueStatusBody').innerHTML, /file-state-generated-at/, 'panel must not combine disk state with projection gate');
assert.match(integrated.elements.get('queueStatusBody').innerHTML, /projection-only queue task/, 'panel queue details must come from the bound projection snapshot');
assert.doesNotMatch(integrated.elements.get('queueStatusBody').innerHTML, /file-only queue task/, 'panel must not mix queue details from a second file read');

integrated = runSnapshotPanelCase('active receipt passed', {
  uiProjection: makeBoundUiProjection(makeQueueState(), { passed: true, reason: 'Round 1 receipt passed' }),
}, {
  expectedStale: false,
  expectedGate: true,
  expectedPrimary: { id: 'ADVANCE_ROUND', enabled: true },
  expectedPanelClass: 'queue-panel',
  panelText: /可前進/,
});
assert.equal(integrated.state.buttons.get('btnAdvanceSeoGeoRound').disabled, false, 'passed receipt enables direct Advance');

const staleReason = 'source_sha_mismatch:src/page.tsx';
const staleState = makeQueueState();
integrated = runSnapshotPanelCase('stale provenance', {
  stateDoc: staleState,
  provenance: { stale: true, status: 'stale_plan', reasons: [staleReason] },
  uiProjection: makeBoundUiProjection(staleState, { consistent: false, reason: staleReason }),
}, {
  expectedStale: true,
  expectedGate: false,
  expectedPrimary: { id: 'NONE', enabled: false },
  expectedPanelClass: 'queue-panel error',
  panelText: /source_sha_mismatch/,
});
assert.equal(integrated.state.buttons.get('btnAdvanceSeoGeoRound').disabled, true, 'stale provenance disables direct Advance');
assert.equal(integrated.state.buttons.get('btnCopySeoGeoAiPrompt').disabled, true, 'stale provenance disables direct Copy');

const projectionErrorState = makeQueueState();
integrated = runSnapshotPanelCase('missing UI projection', {
  stateDoc: projectionErrorState,
  uiProjection: null,
}, {
  expectedStale: true,
  expectedGate: false,
  expectedPrimary: { id: 'NONE', enabled: false },
  expectedPanelClass: 'queue-panel error',
  panelText: /UI projection 不屬於目前 queue／Round/,
});

const identityState = makeQueueState();
integrated = runSnapshotPanelCase('UI projection queue identity mismatch', {
  stateDoc: identityState,
  uiProjection: makeBoundUiProjection(identityState, {
    passed: false,
    reason: 'projection points to another queue',
    identity: { queue_id: 'other-queue' },
  }),
}, {
  expectedStale: true,
  expectedGate: false,
  expectedPrimary: { id: 'NONE', enabled: false },
  expectedPanelClass: 'queue-panel error',
  panelText: /projection points to another queue/,
});

const roundMismatchState = makeQueueState();
integrated = runSnapshotPanelCase('UI projection active round mismatch', {
  stateDoc: roundMismatchState,
  uiProjection: makeBoundUiProjection(roundMismatchState, {
    passed: false,
    reason: 'projection is for round 2',
    round: 2,
  }),
}, {
  expectedStale: true,
  expectedGate: false,
  expectedPrimary: { id: 'NONE', enabled: false },
  expectedPanelClass: 'queue-panel error',
  panelText: /projection is for round 2/,
});

const inconsistentState = makeQueueState();
integrated = runSnapshotPanelCase('effective workflow identity mismatch', {
  stateDoc: inconsistentState,
  queueDoc: makeQueueDocument({ queue_id: 'different-queue' }),
  effectiveProjection: { consistency: { valid: false, reasons: ['queue_state_identity_mismatch'] }, effective: { status: 'inconsistent' } },
  provenance: { stale: false, status: 'current', reasons: [] },
  uiProjection: makeBoundUiProjection(inconsistentState, { consistent: false, reason: 'queue_state_identity_mismatch' }),
}, {
  expectedStale: true,
  expectedGate: false,
  expectedPrimary: { id: 'NONE', enabled: false },
  expectedPanelClass: 'queue-panel error',
  panelText: /queue_state_identity_mismatch/,
});

integrated = runSnapshotPanelCase('missing queue state', {
  stateDoc: null,
  queueDoc: null,
  uiProjection: makeProjection({ state: 'inconsistent', id: 'NONE', enabled: false, reason: 'queue state missing', consistent: false }),
}, {
  expectedPrimary: { id: 'NONE', enabled: false },
  expectedPanelClass: 'queue-panel warn',
  panelText: /工作佇列尚未建立/,
});
assert.equal(integrated.state.buttons.get('btnCopySeoGeoAiPrompt').disabled, true, 'missing state disables direct Copy');
assert.equal(integrated.state.buttons.get('btnAdvanceSeoGeoRound').disabled, true, 'missing state disables direct Advance');

console.log('PASS weekly SOP HTA controls projection tests');
console.log('  primary actions: observation, active receipt wait/pass, local validation, deployment, inconsistency and projection error');
console.log('  secondary deployment buttons, workflow panel messages, click-time stale-action gate and guarded auto-deploy confirmation');
console.log('  actual getQueueSnapshot/refreshQueueStatus VM cases: shared gate, stale provenance, projection error, queue identity, round identity and missing state');
