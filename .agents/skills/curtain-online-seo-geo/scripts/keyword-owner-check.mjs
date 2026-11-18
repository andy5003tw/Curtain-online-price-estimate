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
  const registry = path.join(projectRoot, 'Weekly SOP', 'config', 'target-registry.json');
  if (fs.existsSync(registry)) return registry;
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
  return owner === '/' || owner === 'https://online.hong-sen.com/' || /^https:\/\/online\.hong-sen\.com\/\S+/.test(owner) || /^\/\S+/.test(owner);
}

function normalizeKeyword(value) {
  return String(value || '')
    .normalize('NFKC')
    .toLocaleLowerCase('zh-Hant')
    .replace(/[\s\-_/｜|、，,。．.]+/g, '');
}

function readProducts() {
  const sourcePath = path.join(projectRoot, 'src', 'data', 'products.ts');
  const source = readText(sourcePath);
  const starts = [...source.matchAll(/^\s*"id"\s*:\s*"([^"]+)"/gm)];
  const products = [];

  for (let index = 0; index < starts.length; index += 1) {
    const start = starts[index].index;
    const end = index + 1 < starts.length ? starts[index + 1].index : source.length;
    const block = source.slice(start, end);
    const id = starts[index][1];
    const slug = block.match(/^\s*"slug"\s*:\s*"([^"]+)"/m)?.[1] || '';
    const primaryKeyword = block.match(/^\s*"primaryKeyword"\s*:\s*"([^"]+)"/m)?.[1] || '';
    if (id && slug && primaryKeyword) products.push({ id, slug, primaryKeyword });
  }

  return { sourcePath, products };
}

function validateRegistry(inputFile, errors, warnings) {
  let registry;
  try {
    registry = JSON.parse(readText(inputFile));
  } catch (error) {
    errors.push(`Invalid target registry JSON: ${error.message}`);
    return { rowCount: 0, keywordOwners: new Map(), activeTargets: [] };
  }

  const activeTargets = Array.isArray(registry.targets)
    ? registry.targets.filter(target => target && target.status === 'active')
    : [];
  if (!activeTargets.length) errors.push('Target registry has no active targets.');

  const keywordOwners = new Map();
  const clusterIds = new Set();

  for (const [index, target] of activeTargets.entries()) {
    const rowNumber = index + 1;
    const clusterId = String(target.clusterId || '').trim();
    const keyword = String(target.primaryKeyword || '').trim();
    const owner = String(target.ownerUrl || '').trim();

    if (!clusterId) errors.push(`Target ${rowNumber}: clusterId is empty.`);
    if (clusterIds.has(clusterId)) errors.push(`Duplicate clusterId: ${clusterId}`);
    clusterIds.add(clusterId);
    if (!keyword) errors.push(`Target ${clusterId || rowNumber}: primaryKeyword is empty.`);
    if (!validOwner(owner)) errors.push(`Target ${clusterId || rowNumber}: invalid ownerUrl: ${owner || '(empty)'}`);

    const terms = [keyword, ...(Array.isArray(target.variants) ? target.variants : [])];
    const seenInTarget = new Set();
    for (const term of terms) {
      const normalized = normalizeKeyword(term);
      if (!normalized || seenInTarget.has(normalized)) continue;
      seenInTarget.add(normalized);
      if (!keywordOwners.has(normalized)) keywordOwners.set(normalized, { display: term, owners: new Set() });
      keywordOwners.get(normalized).owners.add(owner);
    }
  }

  for (const { display, owners } of keywordOwners.values()) {
    if (owners.size > 1) {
      errors.push(`Normalized keyword "${display}" maps to multiple owner pages: ${[...owners].join(', ')}`);
    }
  }

  const { sourcePath, products } = readProducts();
  if (!products.length) {
    errors.push(`Could not parse active products from ${rel(sourcePath)}.`);
  }

  const targetByCluster = new Map(activeTargets.map(target => [String(target.clusterId || ''), target]));
  for (const product of products) {
    const clusterId = `product-${product.id}`;
    const target = targetByCluster.get(clusterId);
    const expectedOwner = `/products/${product.slug}/`;
    if (!target) {
      errors.push(`Missing registry target for ${product.id} (${product.primaryKeyword}).`);
      continue;
    }
    if (target.ownerUrl !== expectedOwner) {
      errors.push(`${clusterId}: ownerUrl must be ${expectedOwner}, found ${target.ownerUrl}.`);
    }
    if (target.primaryKeyword !== product.primaryKeyword) {
      errors.push(`${clusterId}: primaryKeyword must match products.ts (${product.primaryKeyword}), found ${target.primaryKeyword}.`);
    }
  }

  const productTargets = activeTargets.filter(target => String(target.clusterId || '').startsWith('product-'));
  if (productTargets.length !== products.length) {
    errors.push(`Product registry coverage mismatch: products.ts=${products.length}, registry=${productTargets.length}.`);
  }

  const homeTarget = activeTargets.find(target => target.primaryKeyword === '窗簾');
  if (!homeTarget || homeTarget.ownerUrl !== '/') {
    errors.push('Core keyword "窗簾" must have homepage ownerUrl "/".');
  }

  if (activeTargets.length !== products.length + 1) {
    warnings.push(`Expected one core target plus all products (${products.length + 1}); found ${activeTargets.length}.`);
  }

  return { rowCount: activeTargets.length, keywordOwners, activeTargets };
}

function validateMarkdown(inputFile, errors, warnings) {
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
      if (!validOwner(owner)) errors.push(`Row ${rowNumber}: owner page for "${keyword}" has an unexpected format: ${owner}`);
      const normalized = normalizeKeyword(keyword);
      if (!keywordOwners.has(normalized)) keywordOwners.set(normalized, { display: keyword, owners: new Set() });
      keywordOwners.get(normalized).owners.add(owner);
      const rowKey = `${keyword} -> ${owner}`;
      duplicateRows.set(rowKey, (duplicateRows.get(rowKey) || 0) + 1);
    }
  }

  for (const { display, owners } of keywordOwners.values()) {
    if (owners.size > 1) errors.push(`Keyword "${display}" maps to multiple owner pages: ${[...owners].join(', ')}`);
  }
  for (const [rowKey, count] of duplicateRows.entries()) {
    if (count > 1) warnings.push(`Duplicate keyword-owner row appears ${count} times: ${rowKey}`);
  }
  return { rowCount: parsed.rows.length, keywordOwners };
}

const inputFile = resolveInputFile();
const errors = [];
const warnings = [];

if (!inputFile || !fs.existsSync(inputFile)) {
  console.error('Keyword owner check failed: target registry or keyword pool file not found.');
  process.exit(1);
}

const result = path.extname(inputFile).toLowerCase() === '.json'
  ? validateRegistry(inputFile, errors, warnings)
  : validateMarkdown(inputFile, errors, warnings);

console.log('# Keyword Owner Check');
console.log('');
console.log(`- File: \`${rel(inputFile)}\``);
console.log(`- Rows checked: ${result.rowCount}`);
console.log(`- Unique normalized keywords: ${result.keywordOwners.size}`);
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
