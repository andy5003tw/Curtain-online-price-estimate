import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const STATE_FILE = 'seo-geo-action-queue-state.json';
const QUEUE_FILE = 'seo-geo-action-queue.json';
const RECEIPT_FILE = 'seo-geo-validation-receipt.json';
const RECEIPT_RELATIVE_PATH = 'latest/seo-geo-validation-receipt.json';
export const FIXED_REQUIRED_VALIDATIONS = Object.freeze([
  'node .agents/skills/curtain-online-seo-geo/scripts/keyword-owner-check.mjs',
  'npm.cmd run build',
  'npm.cmd run seo:check',
  'npm.cmd run seo:preflight',
]);

function asArray(value) {
  if (value === null || typeof value === 'undefined') return [];
  return Array.isArray(value) ? value : [value];
}

function uniqueSortedStrings(values) {
  const seen = Object.create(null);
  const result = [];
  for (const entry of asArray(values)) {
    let value = String(entry === null || typeof entry === 'undefined' ? '' : entry).trim();
    if (value && !seen[value]) {
      seen[value] = true;
      result.push(value);
    }
  }
  return result.sort();
}

function sameStringSet(left, right) {
  const a = uniqueSortedStrings(left);
  const b = uniqueSortedStrings(right);
  return a.length === b.length && a.every((value, index) => value === b[index]);
}

function findRoundItem(items, round) {
  for (const item of asArray(items)) {
    if (item && Number(item.round) === Number(round)) return item;
  }
  return null;
}

function normalizeActionFingerprints(values, expectedActionIds) {
  const result = { valid: true, reason: '', ids: [], map: Object.create(null) };
  if (values === null || typeof values === 'undefined') return result;
  expectedActionIds = asArray(expectedActionIds);

  function add(actionId, fingerprint) {
    actionId = String(actionId || '').trim();
    fingerprint = String(fingerprint || '').trim().toLowerCase();
    if (!actionId || !fingerprint) {
      result.valid = false;
      result.reason = 'action_fingerprints 含空白 action_id 或 fingerprint';
      return;
    }
    const key = `$${actionId}`;
    if (typeof result.map[key] !== 'undefined' && result.map[key] !== fingerprint) {
      result.valid = false;
      result.reason = `action_id ${actionId} 有衝突 fingerprint`;
      return;
    }
    if (typeof result.map[key] === 'undefined') result.ids.push(actionId);
    result.map[key] = fingerprint;
  }

  if (Array.isArray(values)) {
    for (let index = 0; index < values.length; index += 1) {
      const entry = values[index] || {};
      // Legacy queue/state/prompt data stores fingerprints aligned to action_ids;
      // receipts store objects with explicit action_id/fingerprint pairs.
      if (typeof entry === 'string') {
        add(expectedActionIds[index], entry);
      } else {
        add(entry.action_id, entry.fingerprint || entry.action_fingerprint);
      }
    }
  } else if (typeof values === 'object') {
    if (values.action_id || values.fingerprint) {
      add(values.action_id, values.fingerprint);
    } else {
      for (const property of Object.keys(values)) add(property, values[property]);
    }
  } else {
    result.valid = false;
    result.reason = 'action_fingerprints 格式錯誤';
  }
  result.ids = uniqueSortedStrings(result.ids);
  return result;
}

function getActionFingerprintValue(set, actionId) {
  return set && set.map ? set.map[`$${String(actionId)}`] : null;
}

function sameActionFingerprints(left, right) {
  if (!left || !right || !left.valid || !right.valid || !sameStringSet(left.ids, right.ids)) return false;
  return left.ids.every((actionId) => getActionFingerprintValue(left, actionId) === getActionFingerprintValue(right, actionId));
}

function appendCommandValues(target, values) {
  for (const value of asArray(values)) {
    if (value === null || typeof value === 'undefined') continue;
    for (const line of String(value).split(/\r?\n/)) {
      const command = line.trim();
      if (command) target.push(command);
    }
  }
}

function normalizeRequiredValidations(values) {
  const commands = [];
  appendCommandValues(commands, values);
  return uniqueSortedStrings(commands);
}

function getRoundContract(state, queue, round) {
  const prompt = findRoundItem(state.prompt_files, round);
  const stateRound = findRoundItem(state.rounds, round);
  const queueRound = queue ? findRoundItem(queue.rounds, round) : null;
  const actionIdSources = [];

  if (prompt && uniqueSortedStrings(prompt.action_ids).length) {
    actionIdSources.push({ name: 'prompt_files', values: uniqueSortedStrings(prompt.action_ids) });
  }
  if (stateRound && uniqueSortedStrings(stateRound.action_ids).length) {
    actionIdSources.push({ name: 'state.rounds', values: uniqueSortedStrings(stateRound.action_ids) });
  }
  if (queueRound && uniqueSortedStrings(queueRound.action_ids).length) {
    actionIdSources.push({ name: 'queue.rounds', values: uniqueSortedStrings(queueRound.action_ids) });
  }

  const queueActions = queueRound ? asArray(queueRound.actions) : [];
  const queueActionIdsInOrder = [];
  for (const action of queueActions) {
    if (action && action.action_id) queueActionIdsInOrder.push(action.action_id);
  }
  const queueActionIds = uniqueSortedStrings(queueActionIdsInOrder);
  if (queueActionIds.length) actionIdSources.push({ name: 'queue.actions', values: queueActionIds });

  if (!actionIdSources.length) {
    return { valid: false, reason: `Round ${round} 缺少 action_ids`, actionIds: [], requiredValidations: [] };
  }
  const actionIds = actionIdSources[0].values;
  for (let sourceIndex = 1; sourceIndex < actionIdSources.length; sourceIndex += 1) {
    if (!sameStringSet(actionIds, actionIdSources[sourceIndex].values)) {
      return {
        valid: false,
        reason: `Round ${round} action_ids 在 ${actionIdSources[0].name} 與 ${actionIdSources[sourceIndex].name} 不一致`,
        actionIds: [],
        requiredValidations: [],
      };
    }
  }

  const fingerprintSources = [];
  function addFingerprintSource(name, values, sourceActionIds) {
    if (values === null || typeof values === 'undefined') return;
    const normalized = normalizeActionFingerprints(values, sourceActionIds);
    if (!normalized.valid) {
      fingerprintSources.push({ name, values: normalized, invalid: true });
    } else if (normalized.ids.length) {
      fingerprintSources.push({ name, values: normalized, invalid: false });
    }
  }
  addFingerprintSource('prompt_files', prompt ? prompt.action_fingerprints : null, prompt ? prompt.action_ids : []);
  addFingerprintSource('state.rounds', stateRound ? stateRound.action_fingerprints : null, stateRound ? stateRound.action_ids : []);
  addFingerprintSource('queue.rounds', queueRound ? queueRound.action_fingerprints : null, queueRound ? queueRound.action_ids : []);
  addFingerprintSource('queue.actions', queueActions, queueActionIdsInOrder);
  if (!fingerprintSources.length) {
    return { valid: false, reason: `Round ${round} 缺少 action_fingerprints`, actionIds, requiredValidations: [] };
  }
  for (const source of fingerprintSources) {
    if (source.invalid) {
      return {
        valid: false,
        reason: `${source.name} action_fingerprints 無效：${source.values.reason}`,
        actionIds,
        requiredValidations: [],
      };
    }
    if (!sameStringSet(source.values.ids, actionIds)) {
      return {
        valid: false,
        reason: `${source.name} action_fingerprints 未完整對應 action_ids`,
        actionIds,
        requiredValidations: [],
      };
    }
  }
  const actionFingerprintSet = fingerprintSources[0].values;
  for (let index = 1; index < fingerprintSources.length; index += 1) {
    if (!sameActionFingerprints(actionFingerprintSet, fingerprintSources[index].values)) {
      return {
        valid: false,
        reason: `Round ${round} action_fingerprints 在 ${fingerprintSources[0].name} 與 ${fingerprintSources[index].name} 不一致`,
        actionIds,
        requiredValidations: [],
      };
    }
  }

  const actionFingerprints = actionIds.map((actionId) => ({
    action_id: actionId,
    fingerprint: getActionFingerprintValue(actionFingerprintSet, actionId),
  }));

  let stateCommands = [];
  let queueCommands = [];
  if (stateRound) appendCommandValues(stateCommands, stateRound.required_validations);
  if (queueRound) appendCommandValues(queueCommands, queueRound.required_validations);
  if (!queueCommands.length) {
    for (const action of queueActions) {
      if (!action) continue;
      appendCommandValues(queueCommands, action.validationCommands || action.required_validations);
    }
  }
  stateCommands = uniqueSortedStrings(stateCommands);
  queueCommands = uniqueSortedStrings(queueCommands);
  if (stateCommands.length && queueCommands.length && !sameStringSet(stateCommands, queueCommands)) {
    return {
      valid: false,
      reason: `Round ${round} required_validations 在 state 與 queue 不一致`,
      actionIds,
      requiredValidations: [],
    };
  }

  const requiredValidations = stateCommands.length ? stateCommands : queueCommands;
  // The old HTA gate allowed an empty command contract. Treat that malformed
  // contract as blocked so it can never look like a passing receipt gate.
  if (!requiredValidations.length) {
    return { valid: false, reason: `Round ${round} 缺少 required_validations`, actionIds, requiredValidations: [] };
  }

  return {
    valid: true,
    reason: '',
    actionIds,
    actionFingerprints,
    actionFingerprintSet,
    actions: queueActions,
    requiredValidations,
  };
}

function normalizeRegistryBinding(binding) {
  binding = binding || {};
  const result = {
    path: String(binding.path || '').replace(/\\/g, '/').replace(/^\/+/, ''),
    sha256: String(binding.sha256 || '').toLowerCase(),
    version: Number(typeof binding.version !== 'undefined' ? binding.version : binding.schema_version),
  };
  result.valid = !!result.path && !!result.sha256 && !Number.isNaN(result.version);
  return result;
}

function sameRegistryBinding(left, right) {
  left = normalizeRegistryBinding(left);
  right = normalizeRegistryBinding(right);
  return left.valid && right.valid && left.path === right.path && left.sha256 === right.sha256 && left.version === right.version;
}

function normalizeSnapshotWindow(windowBinding) {
  windowBinding = windowBinding || {};
  const query = windowBinding.query_baseline || {};
  const page = windowBinding.page_baseline || {};
  const result = {
    inputSha256: String(windowBinding.sha256 || '').toLowerCase(),
    manifestSha256: String(windowBinding.manifest_sha256 || '').toLowerCase(),
    querySha256: String(query.sha256 || '').toLowerCase(),
    pageSha256: String(page.sha256 || '').toLowerCase(),
  };
  result.valid = !!result.inputSha256 && !!result.manifestSha256 && !!result.querySha256 && !!result.pageSha256;
  return result;
}

function sameSnapshotWindow(left, right) {
  left = normalizeSnapshotWindow(left);
  right = normalizeSnapshotWindow(right);
  return left.valid && right.valid && left.inputSha256 === right.inputSha256 &&
    left.manifestSha256 === right.manifestSha256 && left.querySha256 === right.querySha256 &&
    left.pageSha256 === right.pageSha256;
}

function sameSnapshotBinding(left, right) {
  left = left || {};
  right = right || {};
  return sameSnapshotWindow(left['7d'], right['7d']) && sameSnapshotWindow(left['28d'], right['28d']);
}

function usesWindowsPaths(root) {
  return /^[A-Za-z]:[\\/]/.test(root) || /^\\\\/.test(root);
}

function resolveRootPath(root, ...parts) {
  return usesWindowsPaths(root) ? path.win32.resolve(root, ...parts) : path.resolve(root, ...parts);
}

function resolveManifestPath(root, value) {
  let normalized = String(value || '').replace(/\//g, '\\');
  const absoluteWindows = /^[A-Za-z]:\\/.test(normalized) || /^\\\\/.test(normalized);
  if (absoluteWindows) return usesWindowsPaths(root) ? path.win32.resolve(normalized) : path.resolve(normalized.replace(/\\/g, path.sep));
  normalized = normalized.replace(/^\\+/, '');
  return usesWindowsPaths(root)
    ? path.win32.resolve(root, normalized)
    : path.resolve(root, normalized.replace(/\\/g, path.sep));
}

function makeResult({ passed, reason, round, state, health = 'ok', error = '' }) {
  const status = health === 'error' ? 'error' : (passed ? 'passed' : 'blocked');
  const result = {
    schema_version: 1,
    status,
    health,
    ok: passed === true,
    passed: passed === true,
    reason: String(reason || ''),
    round: Number.isFinite(Number(round)) ? Number(round) : null,
    queue_id: state && typeof state.queue_id !== 'undefined' ? state.queue_id : null,
    cycle_key: state && typeof state.cycle_key !== 'undefined' ? state.cycle_key : null,
  };
  if (error) result.error = String(error);
  return result;
}

function failClosed(reason, round, state = null, error = '') {
  return makeResult({ passed: false, reason, round, state, health: error ? 'error' : 'ok', error });
}

/**
 * Evaluate the queue-bound receipt gate from Weekly SOP Launcher.hta, then
 * apply the writer's active schema/status and fixed validation preconditions.
 * This keeps the old receipt-binding reasons while preventing a UI pass that
 * complete-seo-geo-round.ps1 or the receipt writer would reject.
 */
export function evaluateRoundGate({ root, state, queue, receipt, round }) {
  try {
    if (!state || typeof state !== 'object') return failClosed('queue state 無法讀取', round, state, 'state is required');

    const fixedReceiptPath = resolveRootPath(root, 'latest', RECEIPT_FILE);
    if (!state.receipt_path) {
      return failClosed('queue state 缺少 receipt_path', round, state);
    }
    const receiptPath = resolveManifestPath(root, state.receipt_path);
    if (receiptPath.toLowerCase() !== fixedReceiptPath.toLowerCase()) {
      return failClosed(`receipt_path 必須是 ${RECEIPT_RELATIVE_PATH}`, round, state);
    }

    const contract = getRoundContract(state, queue, round);
    if (!contract.valid) return failClosed(contract.reason, round, state);
    if (!queue) return failClosed('缺少 queue JSON，無法核對 receipt binding', round, state);
    if (String(queue.queue_id || '') !== String(state.queue_id || '') ||
        String(queue.cycle_key || '') !== String(state.cycle_key || '')) {
      return failClosed('queue/state 的 queue_id 或 cycle_key 不一致', round, state);
    }

    const sourceFingerprintBefore = String(state.source_fingerprint || '').toLowerCase();
    if (!sourceFingerprintBefore || sourceFingerprintBefore !== String(queue.source_fingerprint || '').toLowerCase()) {
      return failClosed('queue/state 的 source_fingerprint 不一致', round, state);
    }
    if (!sameRegistryBinding(state.registry, queue.registry)) {
      return failClosed('queue/state 的 registry binding 不一致', round, state);
    }
    if (!sameSnapshotBinding(state.snapshot, queue.snapshot)) {
      return failClosed('queue/state 的 7d/28d snapshot SHA binding 不一致', round, state);
    }
    if (!receipt) return failClosed(`尚未收到 Round ${round} 驗證 receipt`, round, state);
    if (String(receipt.queue_id || '') !== String(state.queue_id || '')) {
      return failClosed('receipt queue_id 不相符', round, state);
    }
    if (String(receipt.cycle_key || '') !== String(state.cycle_key || '')) {
      return failClosed('receipt cycle_key 不相符', round, state);
    }
    if (Number(receipt.round) !== Number(round)) return failClosed('receipt round 不相符', round, state);
    if (!sameStringSet(receipt.action_ids, contract.actionIds)) {
      return failClosed('receipt action_ids 不相符', round, state);
    }
    const receiptFingerprints = normalizeActionFingerprints(receipt.action_fingerprints, contract.actionIds);
    if (!receiptFingerprints.valid || !sameActionFingerprints(receiptFingerprints, contract.actionFingerprintSet)) {
      return failClosed('receipt action_fingerprints 不相符', round, state);
    }
    if (String(receipt.source_fingerprint_before || '').toLowerCase() !== sourceFingerprintBefore) {
      return failClosed('receipt source_fingerprint_before 不相符', round, state);
    }
    if (!sameRegistryBinding(receipt.registry, state.registry)) {
      return failClosed('receipt registry binding 不相符', round, state);
    }
    if (!sameSnapshotBinding(receipt.snapshot, state.snapshot)) {
      return failClosed('receipt 7d/28d snapshot SHA binding 不相符', round, state);
    }
    if (String(receipt.status || '').toLowerCase() !== 'passed') {
      return failClosed('receipt status 不是 passed', round, state);
    }
    if (String(receipt.result || '') !== 'implemented' && String(receipt.result || '') !== 'no_change_verified') {
      return failClosed('receipt result 無效', round, state);
    }

    const sourceFingerprintAfter = String(receipt.source_fingerprint_after || '').toLowerCase();
    if (!sourceFingerprintAfter) return failClosed('receipt 缺少 source_fingerprint_after', round, state);
    if (receipt.result === 'implemented' && sourceFingerprintAfter === sourceFingerprintBefore) {
      return failClosed('implemented receipt 的 source fingerprint 未變更', round, state);
    }
    if (receipt.result === 'no_change_verified' && sourceFingerprintAfter !== sourceFingerprintBefore) {
      return failClosed('no_change_verified receipt 的 source fingerprint 不應變更', round, state);
    }

    const validationResults = asArray(receipt.validation_results);
    for (const required of contract.requiredValidations) {
      const foundPassed = validationResults.some((result) => result &&
        String(result.command || '') === required &&
        String(result.status || '').toLowerCase() === 'passed' &&
        Number(result.exit_code) === 0);
      if (!foundPassed) return failClosed(`必要驗證未通過：${required}`, round, state);
    }

    // Keep the projection aligned with complete-seo-geo-round.ps1 and the
    // receipt writer's fixed validation contract. The legacy HTA gate above is
    // intentionally evaluated first so these failures remain diagnosable as
    // additional backend preconditions.
    if (Number(state.schema_version) !== 2 || Number(queue.schema_version) !== 2) {
      return failClosed('queue/state schema_version 必須為 2', round, state);
    }
    if (String(state.status || '') !== 'active' || String(queue.status || '') !== 'active') {
      return failClosed('queue/state status 必須為 active', round, state);
    }
    if (Number(state.active_round) !== Number(round)) {
      return failClosed('Round 不符合 queue state active_round', round, state);
    }

    const strictRoundSources = [
      { name: 'state.rounds', item: findRoundItem(state.rounds, round) },
      { name: 'queue.rounds', item: findRoundItem(queue.rounds, round) },
      { name: 'prompt_files', item: findRoundItem(state.prompt_files, round) },
    ];
    for (const source of strictRoundSources) {
      const commands = normalizeRequiredValidations(source.item && source.item.required_validations);
      if (!sameStringSet(commands, FIXED_REQUIRED_VALIDATIONS)) {
        return failClosed(`${source.name}.required_validations 必須符合 complete writer 固定四命令`, round, state);
      }
    }

    const strictResults = asArray(receipt.validation_results);
    const strictResultCommands = [];
    const seenCommands = Object.create(null);
    for (const result of strictResults) {
      const command = String(result && result.command || '').trim();
      if (!command) {
        return failClosed('receipt validation_results 必須恰好包含固定四命令且全部 passed、exit_code 0', round, state);
      }
      if (seenCommands[command]) {
        return failClosed('receipt validation_results 不可包含重複 command', round, state);
      }
      seenCommands[command] = true;
      strictResultCommands.push(command);
      if (String(result.status || '').toLowerCase() !== 'passed' || Number(result.exit_code) !== 0) {
        return failClosed(`receipt validation_results 未通過：${command}`, round, state);
      }
    }
    if (!sameStringSet(strictResultCommands, FIXED_REQUIRED_VALIDATIONS)) {
      return failClosed('receipt validation_results 必須恰好包含固定四命令且全部 passed、exit_code 0', round, state);
    }

    return makeResult({ passed: true, reason: `Round ${round} receipt 驗證通過`, round, state });
  } catch (error) {
    return failClosed('Round receipt gate 後端執行失敗', round, state, error instanceof Error ? error.message : String(error));
  }
}

function readJsonIfExists(filePath) {
  if (!fs.existsSync(filePath)) return null;
  const stat = fs.statSync(filePath);
  if (!stat.isFile()) throw new Error(`Expected a file: ${filePath}`);
  // PowerShell 7 may emit UTF-8 JSON with a BOM; ConvertFrom-Json accepts it,
  // so strip the BOM here to keep the Node reader compatible with those files.
  return JSON.parse(fs.readFileSync(filePath, 'utf8').replace(/^\uFEFF/, ''));
}

function parseRuntimeRoot(argv) {
  const rootIndex = argv.indexOf('--runtime-root');
  if (rootIndex < 0 || !argv[rootIndex + 1] || argv[rootIndex + 1].startsWith('--')) {
    throw new Error('Usage: node scripts/seo-geo-round-gate.mjs --runtime-root <path>');
  }
  return path.resolve(argv[rootIndex + 1]);
}

function findWeeklyRoot(runtimeRoot) {
  const directStatePath = resolveRootPath(runtimeRoot, 'latest', STATE_FILE);
  if (fs.existsSync(directStatePath)) return runtimeRoot;
  const nestedWeeklyRoot = resolveRootPath(runtimeRoot, 'Weekly SOP');
  if (fs.existsSync(resolveRootPath(nestedWeeklyRoot, 'latest', STATE_FILE))) return nestedWeeklyRoot;
  throw new Error(`Queue state not found under RuntimeRoot: ${runtimeRoot}`);
}

function runCli(argv) {
  let state = null;
  let round = null;
  try {
    const runtimeRoot = parseRuntimeRoot(argv);
    const root = findWeeklyRoot(runtimeRoot);
    state = readJsonIfExists(resolveRootPath(root, 'latest', STATE_FILE));
    if (!state) throw new Error('Queue state file is missing.');
    round = Number(state.active_round || state.next_round || 1);
    const queue = readJsonIfExists(resolveRootPath(root, 'latest', QUEUE_FILE));
    const receipt = readJsonIfExists(resolveRootPath(root, 'latest', RECEIPT_FILE));
    const result = evaluateRoundGate({ root, state, queue, receipt, round });
    process.stdout.write(`${JSON.stringify(result)}\n`);
    return result.health === 'error' ? 1 : 0;
  } catch (error) {
    const result = failClosed('Round receipt gate 後端資料讀取失敗', round, state, error instanceof Error ? error.message : String(error));
    process.stdout.write(`${JSON.stringify(result)}\n`);
    return 1;
  }
}

const invokedPath = process.argv[1] ? pathToFileURL(path.resolve(process.argv[1])).href : '';
if (invokedPath && invokedPath === import.meta.url) process.exitCode = runCli(process.argv.slice(2));
