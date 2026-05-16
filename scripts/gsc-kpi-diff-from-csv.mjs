import fs from 'node:fs';
import path from 'node:path';

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (!token.startsWith('--')) continue;
    const key = token.slice(2);
    const next = argv[i + 1];
    if (!next || next.startsWith('--')) {
      out[key] = true;
      continue;
    }
    out[key] = next;
    i += 1;
  }
  return out;
}

function ensureFile(filePath, label) {
  if (!filePath) {
    throw new Error(`Missing --${label}`);
  }
  if (!fs.existsSync(filePath)) {
    throw new Error(`Missing file: ${filePath}`);
  }
}

function parseCsvLine(line) {
  const row = [];
  let cur = '';
  let i = 0;
  let inQuotes = false;
  while (i < line.length) {
    const ch = line[i];
    if (ch === '"') {
      if (inQuotes && line[i + 1] === '"') {
        cur += '"';
        i += 2;
        continue;
      }
      inQuotes = !inQuotes;
      i += 1;
      continue;
    }
    if (ch === ',' && !inQuotes) {
      row.push(cur);
      cur = '';
      i += 1;
      continue;
    }
    cur += ch;
    i += 1;
  }
  row.push(cur);
  return row;
}

function readCsv(filePath) {
  let raw = fs.readFileSync(filePath, 'utf8');
  raw = raw.replace(/^\uFEFF/, '');
  const lines = raw.split(/\r?\n/).filter((line) => line.trim() !== '');
  if (lines.length < 2) return [];
  const headers = parseCsvLine(lines[0]).map((h) => h.trim());
  const rows = [];
  for (let i = 1; i < lines.length; i += 1) {
    const cols = parseCsvLine(lines[i]);
    const item = {};
    headers.forEach((h, idx) => {
      item[h] = (cols[idx] ?? '').trim();
    });
    rows.push(item);
  }
  return rows;
}

function parseNumber(v) {
  if (v === null || v === undefined) return 0;
  const s = String(v).trim().replace(/,/g, '');
  if (s === '' || s === '-' || s.toLowerCase() === 'n/a') return 0;
  const n = Number.parseFloat(s);
  return Number.isFinite(n) ? n : 0;
}

function parseCtrToRatio(v) {
  if (v === null || v === undefined) return 0;
  const s = String(v).trim();
  if (s === '' || s === '-' || s.toLowerCase() === 'n/a') return 0;
  if (s.endsWith('%')) {
    const n = Number.parseFloat(s.slice(0, -1).replace(/,/g, ''));
    return Number.isFinite(n) ? n / 100 : 0;
  }
  const n = Number.parseFloat(s.replace(/,/g, ''));
  if (!Number.isFinite(n)) return 0;
  return n > 1 ? n / 100 : n;
}

function pick(row, names, fallback = '') {
  for (const n of names) {
    if (Object.prototype.hasOwnProperty.call(row, n)) {
      const val = String(row[n] ?? '').trim();
      if (val !== '') return val;
    }
  }
  return fallback;
}

function normalizeRow(row) {
  const query = pick(row, ['query', 'Query'], '(all queries)');
  const page = pick(row, ['page', 'Page', 'url', 'URL'], '(all pages)');
  const clicks = parseNumber(pick(row, ['clicks', 'Clicks', '點擊'], '0'));
  const impressions = parseNumber(pick(row, ['impressions', 'Impressions', '曝光'], '0'));
  const ctr = parseCtrToRatio(pick(row, ['ctr', 'CTR', '點閱率'], '0'));
  const position = parseNumber(pick(row, ['position', 'Position', '排名'], '0'));
  return { query, page, clicks, impressions, ctr, position };
}

function keyFor(row) {
  return `${row.query}|||${row.page}`;
}

function toMap(rows) {
  const out = new Map();
  for (const raw of rows) {
    const row = normalizeRow(raw);
    const key = keyFor(row);
    const cur = out.get(key);
    if (!cur) {
      out.set(key, { ...row });
      continue;
    }
    cur.clicks += row.clicks;
    cur.impressions += row.impressions;
    cur.ctr = row.ctr;
    cur.position = row.position;
  }
  return out;
}

function pctChange(before, after) {
  if (before === 0) {
    if (after === 0) return 0;
    return null;
  }
  return ((after - before) / before) * 100;
}

function formatInt(n) {
  if (n === null || n === undefined) return '0';
  return Math.round(n).toLocaleString('en-US');
}

function formatNum(n, d = 2) {
  if (n === null || n === undefined || !Number.isFinite(n)) return 'n/a';
  return n.toFixed(d);
}

function formatPct(n) {
  if (n === null || n === undefined || !Number.isFinite(n)) return 'n/a';
  return `${n.toFixed(2)}%`;
}

function formatCtr(ratio) {
  if (!Number.isFinite(ratio)) return 'n/a';
  return `${(ratio * 100).toFixed(2)}%`;
}

function formatPp(v) {
  if (v === null || v === undefined || !Number.isFinite(v)) return 'n/a';
  return `${v.toFixed(2)} pp`;
}

function isQueryReport(rows) {
  if (rows.length === 0) return true;
  return rows.every((r) => r.page === '(all pages)');
}

function urlTitle(page) {
  if (!page || page === '(all pages)') return '';
  try {
    const u = new URL(page);
    const p = u.pathname || '/';
    return p === '/' ? '/ 首頁' : p;
  } catch {
    return page;
  }
}

function statusForObservation(clickDeltaPct, imprDeltaPct, posImprove) {
  const bad =
    (clickDeltaPct !== null && clickDeltaPct <= -30) ||
    (imprDeltaPct !== null && imprDeltaPct <= -30) ||
    (posImprove !== null && posImprove <= -3);
  return bad ? '需檢查' : '觀察';
}

function verdictForDecision(imprDeltaPct, posImprove, ctrDeltaPp) {
  const imprPass = imprDeltaPct !== null && imprDeltaPct > 15;
  const posPass = posImprove !== null && posImprove >= 1;
  const ctrPass = ctrDeltaPp !== null && ctrDeltaPp >= 0.3;
  if (imprPass && posPass && ctrPass) return '通過';
  if (ctrPass || posPass || imprPass) return '觀察';
  return '未達標';
}

function escapeHtml(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function markdownTable(headers, rows) {
  const h = `| ${headers.join(' | ')} |`;
  const sep = `| ${headers.map(() => '---').join(' | ')} |`;
  const body = rows.map((r) => `| ${r.join(' | ')} |`);
  return [h, sep, ...body].join('\n');
}

function markdownToHtml(md) {
  const lines = md.split('\n');
  const out = [];
  let i = 0;

  function flushParagraph(buf) {
    if (!buf.length) return;
    out.push(`<p>${escapeHtml(buf.join(' '))}</p>`);
    buf.length = 0;
  }

  const paragraph = [];
  while (i < lines.length) {
    const line = lines[i];
    if (line.startsWith('# ')) {
      flushParagraph(paragraph);
      out.push(`<h1>${escapeHtml(line.slice(2))}</h1>`);
      i += 1;
      continue;
    }
    if (line.startsWith('## ')) {
      flushParagraph(paragraph);
      out.push(`<h2>${escapeHtml(line.slice(3))}</h2>`);
      i += 1;
      continue;
    }
    if (line.startsWith('- ')) {
      flushParagraph(paragraph);
      const items = [];
      while (i < lines.length && lines[i].startsWith('- ')) {
        items.push(lines[i].slice(2));
        i += 1;
      }
      out.push('<ul>');
      for (const item of items) {
        out.push(`<li>${escapeHtml(item)}</li>`);
      }
      out.push('</ul>');
      continue;
    }
    if (line.startsWith('|')) {
      flushParagraph(paragraph);
      const tLines = [];
      while (i < lines.length && lines[i].startsWith('|')) {
        tLines.push(lines[i]);
        i += 1;
      }
      if (tLines.length >= 2) {
        const rows = tLines.map((l) =>
          l
            .split('|')
            .slice(1, -1)
            .map((c) => c.trim())
        );
        const header = rows[0];
        const body = rows.slice(2);
        out.push('<table border="1" cellspacing="0" cellpadding="6">');
        out.push('<thead><tr>');
        header.forEach((h) => out.push(`<th>${escapeHtml(h)}</th>`));
        out.push('</tr></thead>');
        out.push('<tbody>');
        for (const r of body) {
          out.push('<tr>');
          r.forEach((c) => out.push(`<td>${escapeHtml(c)}</td>`));
          out.push('</tr>');
        }
        out.push('</tbody></table>');
      } else {
        out.push(`<pre>${escapeHtml(tLines.join('\n'))}</pre>`);
      }
      continue;
    }
    if (line.trim() === '') {
      flushParagraph(paragraph);
      i += 1;
      continue;
    }
    paragraph.push(line);
    i += 1;
  }
  flushParagraph(paragraph);

  return `<!doctype html>
<html lang="zh-Hant">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>GSC KPI Diff Report</title>
  <style>
    body { font-family: "Microsoft JhengHei", Arial, sans-serif; margin: 24px; line-height: 1.6; color: #1f2937; }
    h1, h2 { color: #0f172a; }
    table { border-collapse: collapse; width: 100%; margin: 14px 0 22px; font-size: 13px; }
    th { background: #f1f5f9; }
    th, td { border: 1px solid #cbd5e1; vertical-align: top; text-align: left; }
    code { background: #eef2ff; padding: 2px 4px; border-radius: 4px; }
    ul { margin-top: 6px; }
  </style>
</head>
<body>
${out.join('\n')}
</body>
</html>`;
}

function writeReport({ outputPath, fullOutputPath, titleSuffix, periodLabel, trackingStartDate, verdictMode, minImpr, limit, beforeRows, afterRows, seoGeoTotal, seoGeoQueryCount, seoGeoPageCount }) {
  const beforeMap = toMap(beforeRows);
  const afterMap = toMap(afterRows);
  const keys = new Set([...beforeMap.keys(), ...afterMap.keys()]);

  const details = [];
  let beforeClicks = 0;
  let afterClicks = 0;
  let beforeImpr = 0;
  let afterImpr = 0;
  let beforePosWeighted = 0;
  let afterPosWeighted = 0;

  for (const key of keys) {
    const b = beforeMap.get(key) ?? { query: '', page: '', clicks: 0, impressions: 0, ctr: 0, position: 0 };
    const a = afterMap.get(key) ?? { query: b.query, page: b.page, clicks: 0, impressions: 0, ctr: 0, position: 0 };
    const row = {
      query: a.query || b.query,
      page: a.page || b.page,
      beforeClicks: b.clicks,
      afterClicks: a.clicks,
      beforeImpr: b.impressions,
      afterImpr: a.impressions,
      beforeCtr: b.ctr,
      afterCtr: a.ctr,
      beforePos: b.position > 0 ? b.position : null,
      afterPos: a.position > 0 ? a.position : null,
    };

    row.imprDeltaPct = pctChange(row.beforeImpr, row.afterImpr);
    row.clickDeltaPct = pctChange(row.beforeClicks, row.afterClicks);
    row.posImprove =
      row.beforePos !== null && row.afterPos !== null ? row.beforePos - row.afterPos : null;
    row.ctrDeltaPp = (row.afterCtr - row.beforeCtr) * 100;
    row.pageTitle = urlTitle(row.page);
    details.push(row);

    beforeClicks += row.beforeClicks;
    afterClicks += row.afterClicks;
    beforeImpr += row.beforeImpr;
    afterImpr += row.afterImpr;
    if (row.beforePos !== null && row.beforeImpr > 0) beforePosWeighted += row.beforePos * row.beforeImpr;
    if (row.afterPos !== null && row.afterImpr > 0) afterPosWeighted += row.afterPos * row.afterImpr;
  }

  const beforeCtrAll = beforeImpr > 0 ? beforeClicks / beforeImpr : 0;
  const afterCtrAll = afterImpr > 0 ? afterClicks / afterImpr : 0;
  const beforePosAll = beforeImpr > 0 ? beforePosWeighted / beforeImpr : null;
  const afterPosAll = afterImpr > 0 ? afterPosWeighted / afterImpr : null;
  const imprDeltaPctAll = pctChange(beforeImpr, afterImpr);
  const clickDeltaPctAll = pctChange(beforeClicks, afterClicks);
  const posImproveAll =
    beforePosAll !== null && afterPosAll !== null ? beforePosAll - afterPosAll : null;
  const ctrDeltaPpAll = (afterCtrAll - beforeCtrAll) * 100;

  const observationMode = verdictMode === 'observation';
  let overallVerdict = '觀察';
  if (observationMode) {
    overallVerdict = statusForObservation(clickDeltaPctAll, imprDeltaPctAll, posImproveAll);
  } else {
    overallVerdict = verdictForDecision(imprDeltaPctAll, posImproveAll, ctrDeltaPpAll);
  }

  const sorted = details
    .filter((r) => r.afterImpr >= minImpr)
    .sort((a, b) => {
      if (b.afterImpr !== a.afterImpr) return b.afterImpr - a.afterImpr;
      if (a.afterCtr !== b.afterCtr) return a.afterCtr - b.afterCtr;
      const aPos = a.afterPos ?? 9999;
      const bPos = b.afterPos ?? 9999;
      return aPos - bPos;
    });

  const mainRows = sorted.slice(0, limit);
  const reportType = isQueryReport(afterRows) ? '查詢' : '網頁';
  const fullCountLabel = `${afterRows.length}`;
  const generatedAt = new Date();
  const generatedText =
    `${generatedAt.getFullYear()}-${String(generatedAt.getMonth() + 1).padStart(2, '0')}-${String(generatedAt.getDate()).padStart(2, '0')} ` +
    `${String(generatedAt.getHours()).padStart(2, '0')}:${String(generatedAt.getMinutes()).padStart(2, '0')}`;

  const suffix = titleSuffix ?? '';
  const title = `# GSC 前後期 KPI 對比報告${suffix}`;
  const rowsTable = mainRows.map((r) => [
    r.pageTitle,
    r.page || '(all pages)',
    r.query || '(all queries)',
    formatInt(r.beforeImpr),
    formatInt(r.afterImpr),
    formatPct(r.imprDeltaPct),
    formatNum(r.beforePos),
    formatNum(r.afterPos),
    formatNum(r.posImprove),
    formatCtr(r.beforeCtr),
    formatCtr(r.afterCtr),
    formatPp(r.ctrDeltaPp),
  ]);

  const kpiRows = observationMode
    ? [
        [
          '點擊變化率',
          formatInt(beforeClicks),
          formatInt(afterClicks),
          formatPct(clickDeltaPctAll),
          '警戒：<=-30%',
          statusForObservation(clickDeltaPctAll, imprDeltaPctAll, posImproveAll),
        ],
        [
          '曝光變化率',
          formatInt(beforeImpr),
          formatInt(afterImpr),
          formatPct(imprDeltaPctAll),
          '警戒：<=-30%',
          statusForObservation(clickDeltaPctAll, imprDeltaPctAll, posImproveAll),
        ],
        [
          '平均排名變化',
          formatNum(beforePosAll),
          formatNum(afterPosAll),
          formatNum(posImproveAll),
          '警戒：退步 >=3',
          statusForObservation(clickDeltaPctAll, imprDeltaPctAll, posImproveAll),
        ],
        [
          'CTR 變化（百分點）',
          formatCtr(beforeCtrAll),
          formatCtr(afterCtrAll),
          formatPp(ctrDeltaPpAll),
          '參考',
          '觀察',
        ],
      ]
    : [
        [
          '曝光成長率',
          formatInt(beforeImpr),
          formatInt(afterImpr),
          formatPct(imprDeltaPctAll),
          '>15%',
          imprDeltaPctAll !== null && imprDeltaPctAll > 15 ? '通過' : '未達標',
        ],
        [
          '平均排名改善',
          formatNum(beforePosAll),
          formatNum(afterPosAll),
          formatNum(posImproveAll),
          '>=1',
          posImproveAll !== null && posImproveAll >= 1 ? '通過' : '未達標',
        ],
        [
          'CTR 提升（百分點）',
          formatCtr(beforeCtrAll),
          formatCtr(afterCtrAll),
          formatPp(ctrDeltaPpAll),
          '>=0.3 pp',
          ctrDeltaPpAll >= 0.3 ? '通過' : '未達標',
        ],
      ];

  const lines = [
    title,
    '',
    `- 產生時間：${generatedText}`,
    `- 改版前 CSV：${path.resolve(args.before)}`,
    `- 改版後 CSV：${path.resolve(args.after)}`,
    `- 報表區間：${periodLabel || 'n/a'}`,
    `- 追蹤起始日：${trackingStartDate || 'n/a'}`,
    `- SEO/GEO 總追蹤筆數：${seoGeoTotal || 0}（查詢 ${seoGeoQueryCount || 0} + 網頁 ${seoGeoPageCount || 0}）`,
    `- 主報表顯示：查詢前 ${args['main-query-limit'] || limit} 筆 / 網頁前 ${args['main-page-limit'] || limit} 筆`,
    `- 完整明細：查詢 ${seoGeoQueryCount || 0} 筆 / 網頁 ${seoGeoPageCount || 0} 筆`,
    observationMode
      ? '- 判讀用途：7 天觀察：用來找異常與微調，不作最終成敗判定。'
      : '- 判讀用途：28 天判定：正式判斷 SEO / GEO 改版成效。',
    '- 改版前日期區間：n/a（CSV 無 date 欄）',
    '- 改版後日期區間：n/a（CSV 無 date 欄）',
    `- 比對鍵數：${details.length}`,
    `- 主表顯示筆數：${mainRows.length}`,
    `- 主表篩選門檻：min-impr=${minImpr}, limit=${limit}`,
    `- 綜合判定：**${overallVerdict}**`,
    '',
    '## KPI 摘要',
    markdownTable(['指標', '改版前', '改版後', '差異', '門檻', '狀態'], kpiRows),
    '',
    `## 決策明細（主報表 ${mainRows.length} 筆，min-impr=${minImpr}，依曝光/CTR/排名機會排序）`,
    markdownTable(
      [
        '網頁中文抬頭',
        '頁面',
        '查詢',
        '改版前曝光',
        '改版後曝光',
        '曝光成長率',
        '改版前排名',
        '改版後排名',
        '排名改善',
        '改版前CTR',
        '改版後CTR',
        'CTR差異(百分點)',
      ],
      rowsTable
    ),
    '',
    '## 判讀說明',
    observationMode
      ? '- 7 天報告只作觀察與微調依據，不作 SEO / GEO 最終成敗判定。'
      : '- 28 天報告可用於正式判定改版是否有效。',
    `- 主報表是決策版，只列出優先處理項目；完整明細保留在 full 檔（本次 ${fullCountLabel} 筆）。`,
    '- 主表排序：先看改版後曝光高，再看 CTR 低，最後看排名 4-20 的微調機會。',
    '- 曝光（Impressions）越高越好。',
    '- 排名（Position）越小越好；排名改善 = 改版前排名 - 改版後排名（正值代表進步）。',
    '- CTR 差異以百分點（pp）表示。',
    '',
  ];

  const md = lines.join('\n');
  const html = markdownToHtml(md);
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, md, 'utf8');
  fs.writeFileSync(outputPath.replace(/\.md$/i, '.html'), html, 'utf8');

  if (fullOutputPath) {
    const fullRows = sorted.map((r) => [
      r.pageTitle,
      r.page || '(all pages)',
      r.query || '(all queries)',
      formatInt(r.beforeImpr),
      formatInt(r.afterImpr),
      formatPct(r.imprDeltaPct),
      formatNum(r.beforePos),
      formatNum(r.afterPos),
      formatNum(r.posImprove),
      formatCtr(r.beforeCtr),
      formatCtr(r.afterCtr),
      formatPp(r.ctrDeltaPp),
    ]);
    const fullMd = [
      `# GSC 前後期 KPI 完整明細${suffix}`,
      '',
      `- 產生時間：${generatedText}`,
      `- 報表類型：${reportType}`,
      `- 明細筆數：${fullRows.length}`,
      '',
      markdownTable(
        [
          '網頁中文抬頭',
          '頁面',
          '查詢',
          '改版前曝光',
          '改版後曝光',
          '曝光成長率',
          '改版前排名',
          '改版後排名',
          '排名改善',
          '改版前CTR',
          '改版後CTR',
          'CTR差異(百分點)',
        ],
        fullRows
      ),
      '',
    ].join('\n');
    const fullHtml = markdownToHtml(fullMd);
    fs.mkdirSync(path.dirname(fullOutputPath), { recursive: true });
    fs.writeFileSync(fullOutputPath, fullMd, 'utf8');
    fs.writeFileSync(fullOutputPath.replace(/\.md$/i, '.html'), fullHtml, 'utf8');
  }
}

const args = parseArgs(process.argv.slice(2));
ensureFile(args.before, 'before');
ensureFile(args.after, 'after');
if (!args.output) {
  throw new Error('Missing --output');
}

const beforeRows = readCsv(args.before);
const afterRows = readCsv(args.after);
const minImpr = Number.parseInt(args['min-impr'] ?? '1', 10);
const limit = Number.parseInt(args.limit ?? '30', 10);

writeReport({
  outputPath: args.output,
  fullOutputPath: args['full-output'],
  titleSuffix: args['title-suffix'] ?? '',
  periodLabel: args['period-label'] ?? 'n/a',
  trackingStartDate: args['tracking-start-date'] ?? 'n/a',
  verdictMode: args['verdict-mode'] ?? 'observation',
  minImpr: Number.isFinite(minImpr) ? minImpr : 1,
  limit: Number.isFinite(limit) ? limit : 30,
  beforeRows,
  afterRows,
  seoGeoTotal: Number.parseInt(args['seo-geo-total'] ?? '0', 10),
  seoGeoQueryCount: Number.parseInt(args['seo-geo-query-count'] ?? '0', 10),
  seoGeoPageCount: Number.parseInt(args['seo-geo-page-count'] ?? '0', 10),
});

console.log('GSC KPI diff report generated.');
