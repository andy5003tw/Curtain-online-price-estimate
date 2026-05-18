#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';

function findProjectRoot(startDir) {
  let current = path.resolve(startDir);
  while (true) {
    if (
      fs.existsSync(path.join(current, 'package.json')) &&
      fs.existsSync(path.join(current, 'plan.md'))
    ) {
      return current;
    }
    const parent = path.dirname(current);
    if (parent === current) return path.resolve(startDir);
    current = parent;
  }
}

const projectRoot = findProjectRoot(process.cwd());

function rel(filePath) {
  return path.relative(projectRoot, filePath).replace(/\\/g, '/');
}

function readText(filePath) {
  try {
    return fs.readFileSync(filePath, 'utf8').replace(/^\uFEFF/, '');
  } catch {
    return '';
  }
}

function listFilesSafe(dirPath) {
  try {
    return fs.readdirSync(dirPath, { withFileTypes: true });
  } catch {
    return [];
  }
}

function latestKeywordPool() {
  const weeklyDir = path.join(projectRoot, 'Weekly SOP');
  const candidates = listFilesSafe(weeklyDir)
    .filter(entry => entry.isFile() && /^12-keyword-pool-v.+\.md$/i.test(entry.name))
    .map(entry => {
      const fullPath = path.join(weeklyDir, entry.name);
      const stat = fs.statSync(fullPath);
      const dateMatch = entry.name.match(/(\d{4}-\d{2}-\d{2})/);
      return {
        fullPath,
        name: entry.name,
        dateKey: dateMatch?.[1] || '',
        mtimeMs: stat.mtimeMs,
      };
    })
    .sort((a, b) => b.dateKey.localeCompare(a.dateKey) || b.mtimeMs - a.mtimeMs);

  return candidates[0] || null;
}

function parseKeywordTable(markdown) {
  const lines = markdown.split(/\r?\n/);
  let header = null;
  const rows = [];

  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed.startsWith('|') || !trimmed.endsWith('|')) continue;
    if (/^\|\s*-+/.test(trimmed)) continue;

    const cells = trimmed
      .split('|')
      .slice(1, -1)
      .map(cell => cell.trim());

    if (!header) {
      if (cells.some(cell => /主攻詞|keyword/i.test(cell))) header = cells;
      continue;
    }

    if (cells.length >= header.length) rows.push(cells);
  }

  if (!header) return { rows: [], keywordIndex: -1, ownerIndex: -1 };

  const keywordIndex = header.findIndex(cell => /主攻詞|keyword/i.test(cell));
  const ownerIndex = header.findIndex(cell => /綁定主頁|owner|page/i.test(cell));
  return { rows, keywordIndex, ownerIndex };
}

function cleanInlineCode(value) {
  return value.replace(/`/g, '').trim();
}

function extractBatchTargets(markdown) {
  const lines = markdown.split(/\r?\n/);
  const targets = [];
  let inSection = false;

  for (const line of lines) {
    if (/^#{2,}\s+.*6\s*頁.*優化順序/i.test(line) || /^#{2,}\s+.*6-page/i.test(line)) {
      inSection = true;
      continue;
    }
    if (inSection && /^##\s+/.test(line)) break;
    if (!inSection) continue;

    const inline = line.match(/`([^`]*(?:https:\/\/online\.hong-sen\.com|\/)[^`]*)`/);
    const rawUrl = inline?.[1] || line.match(/https:\/\/online\.hong-sen\.com\/[^\s)]+/)?.[0];
    if (!rawUrl) continue;

    targets.push(rawUrl.replace(/[。,.，]$/, ''));
  }

  return [...new Set(targets)];
}

function baselineStatus(windowName) {
  const dir = path.join(projectRoot, 'Weekly SOP', 'history', windowName);
  const query = path.join(dir, 'current_query_baseline.normalized.csv');
  const page = path.join(dir, 'current_page_baseline.normalized.csv');
  return {
    query: fs.existsSync(query),
    page: fs.existsSync(page),
  };
}

function packageScript(name) {
  const packageJson = JSON.parse(readText(path.join(projectRoot, 'package.json')) || '{}');
  return packageJson.scripts?.[name] || null;
}

const planPath = path.join(projectRoot, 'plan.md');
const plan = readText(planPath);
const planTitle = plan.match(/^#\s+(.+)$/m)?.[1] || '(missing plan.md title)';
const pool = latestKeywordPool();
const poolMarkdown = pool ? readText(pool.fullPath) : '';
const keywordInfo = parseKeywordTable(poolMarkdown);
const ownerIndex = keywordInfo.ownerIndex;
const owners = ownerIndex >= 0
  ? new Set(keywordInfo.rows.map(row => cleanInlineCode(row[ownerIndex] || '')).filter(Boolean))
  : new Set();
const targets = extractBatchTargets(poolMarkdown);
const sevenDay = baselineStatus('7d');
const twentyEightDay = baselineStatus('28d');

console.log('# Curtain Online SEO/GEO Snapshot');
console.log('');
console.log(`- Project root: \`${projectRoot}\``);
console.log(`- Plan: \`${rel(planPath)}\` - ${planTitle}`);
console.log(`- Latest keyword pool: ${pool ? `\`${rel(pool.fullPath)}\`` : 'not found'}`);
console.log(`- Keyword rows: ${keywordInfo.rows.length}`);
console.log(`- Owner pages: ${owners.size}`);
console.log(`- 7d baseline: query=${sevenDay.query ? 'yes' : 'no'}, page=${sevenDay.page ? 'yes' : 'no'}`);
console.log(`- 28d baseline: query=${twentyEightDay.query ? 'yes' : 'no'}, page=${twentyEightDay.page ? 'yes' : 'no'}`);
console.log(`- Build command: \`npm.cmd run build\`${packageScript('build') ? '' : ' (package script missing)'}`);
console.log(`- SEO check command: \`npm.cmd run seo:check\`${packageScript('seo:check') ? '' : ' (package script missing)'}`);
console.log('');

if (targets.length) {
  console.log('## Latest 6-Page Batch');
  for (const target of targets) {
    console.log(`- ${target}`);
  }
  console.log('');
}

console.log('## Read Next');
console.log('- Ranking batch: `references/seo-batch-workflow.md`');
console.log('- Content/schema edits: `references/content-schema-standards.md`');
console.log('- Build/deploy validation: `references/validation-deploy.md`');
console.log('');
console.log('## Guardrails');
console.log('- Edit source files, not `out/`.');
console.log('- Keep `plan.md` compact; keep completed history in `Phase*.md`.');
console.log('- Static deploy uploads only the contents inside `out/`.');
