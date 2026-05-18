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
        dateKey: dateMatch?.[1] || '',
        mtimeMs: stat.mtimeMs,
      };
    })
    .sort((a, b) => b.dateKey.localeCompare(a.dateKey) || b.mtimeMs - a.mtimeMs);

  return candidates[0]?.fullPath || null;
}

function resolveInputFile() {
  const arg = process.argv[2];
  if (arg) {
    return path.isAbsolute(arg) ? arg : path.join(projectRoot, arg);
  }
  return latestKeywordPool();
}

function parseTable(markdown) {
  const lines = markdown.split(/\r?\n/);
  let header = null;
  const rows = [];

  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed.startsWith('|') || !trimmed.endsWith('|')) continue;
    if (/^\|\s*:?-{3,}/.test(trimmed)) continue;

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

  if (!header) {
    return { header: [], rows: [], keywordIndex: -1, ownerIndex: -1 };
  }

  return {
    header,
    rows,
    keywordIndex: header.findIndex(cell => /主攻詞|keyword/i.test(cell)),
    ownerIndex: header.findIndex(cell => /綁定主頁|owner|page/i.test(cell)),
  };
}

function cleanCell(value) {
  return value
    .replace(/`/g, '')
    .replace(/<br\s*\/?>/gi, ' ')
    .trim();
}

function validOwner(owner) {
  return /^https:\/\/online\.hong-sen\.com\/\S+/.test(owner) || /^\/\S+/.test(owner);
}

const inputFile = resolveInputFile();
const errors = [];
const warnings = [];

if (!inputFile || !fs.existsSync(inputFile)) {
  console.error('Keyword owner check failed: keyword pool file not found.');
  process.exit(1);
}

const parsed = parseTable(readText(inputFile));

if (parsed.keywordIndex < 0) errors.push('Cannot find keyword column. Expected header containing 主攻詞 or keyword.');
if (parsed.ownerIndex < 0) errors.push('Cannot find owner page column. Expected header containing 綁定主頁, owner, or page.');
if (!parsed.rows.length) errors.push('No keyword rows found in the keyword pool table.');

const keywordOwners = new Map();
const duplicateRows = new Map();

if (!errors.length) {
  for (const [index, row] of parsed.rows.entries()) {
    const rowNumber = index + 1;
    const keyword = cleanCell(row[parsed.keywordIndex] || '');
    const owner = cleanCell(row[parsed.ownerIndex] || '');

    if (!keyword) {
      errors.push(`Row ${rowNumber}: keyword is empty.`);
      continue;
    }

    if (!owner || owner === '-') {
      errors.push(`Row ${rowNumber}: keyword "${keyword}" has no owner page.`);
      continue;
    }

    if (!validOwner(owner)) {
      errors.push(`Row ${rowNumber}: owner page for "${keyword}" has an unexpected format: ${owner}`);
    }

    if (!keywordOwners.has(keyword)) keywordOwners.set(keyword, new Set());
    keywordOwners.get(keyword).add(owner);

    const rowKey = `${keyword} -> ${owner}`;
    duplicateRows.set(rowKey, (duplicateRows.get(rowKey) || 0) + 1);
  }
}

for (const [keyword, owners] of keywordOwners.entries()) {
  if (owners.size > 1) {
    errors.push(`Keyword "${keyword}" maps to multiple owner pages: ${[...owners].join(', ')}`);
  }
}

for (const [rowKey, count] of duplicateRows.entries()) {
  if (count > 1) {
    warnings.push(`Duplicate keyword-owner row appears ${count} times: ${rowKey}`);
  }
}

console.log(`# Keyword Owner Check`);
console.log('');
console.log(`- File: \`${rel(inputFile)}\``);
console.log(`- Rows checked: ${parsed.rows.length}`);
console.log(`- Unique keywords: ${keywordOwners.size}`);
console.log('');

if (warnings.length) {
  console.log('## Warnings');
  for (const warning of warnings) console.log(`- ${warning}`);
  console.log('');
}

if (errors.length) {
  console.log('## Errors');
  for (const error of errors) console.log(`- ${error}`);
  process.exit(1);
}

console.log('Keyword owner check passed.');
