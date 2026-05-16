# Curtain Online 網站 SEO、GEO、Schema 主控計畫

## 重要紀錄

- 正式網域：`https://online.hong-sen.com/`。
- 範圍邊界：僅站內 SEO/GEO/Schema；不含站外 SEO 與 GBP。
- 產品網址收斂原則：維持 `Pxxx -> slug` 301 規則，canonical 一律指向語意網址。
- 本檔維護規則：保留重要紀錄 + 已完成里程碑 + 未完成與預定工作；已完成細節維持於 `Phase*.md`。
- 排名目標（2026-05-13 起）：主關鍵字「窗簾」與各產品頁關鍵字，分階段推進至 Google 前 10 名。
- 關鍵字策略：先打 `產品 + 地區` 長尾詞（例：`三重 調光簾 推薦`、`板橋 遮光窗簾`），再回攻高競爭大詞。
- AI 關鍵字推薦策略：先人工 SOP（GSC 7/28 天資料 + 固定 Prompt）再半自動化。
- 固定執行節奏（2026-05-16 起）：每輪改版固定完整執行 6 頁，不拆小批次。
  - `/calculator/`
  - `/location/sanchong/`
  - `/location/taipei/`
  - `/products/roller-blinds/`
  - `/products/zebra-blinds/`
  - `/products/wooden-blinds/`
- 固定上線策略（2026-05-16 起）：`npm.cmd run build` 後，FTP 一律以 `out/` 全量上傳至 `online.hong-sen.com/`。
  - 僅上傳網站輸出物；不把 `plan.md`、`Phase*.md`、`Weekly SOP` 原始資料、`scripts/` 上傳到主機。
- 驗收總原則：
  - `npm.cmd run build` 必須成功。
  - `out/sitemap.xml` 需含有效頁面並排除 legacy `Pxxx`。
  - `robots.txt` 維持單一 sitemap 指向。
  - 代表頁面 metadata（title/description/canonical/OG/Twitter）與 JSON-LD 可解析。
- 現況快照（2026-05-13，local）：
  - `npm.cmd run seo:check`：`SEO check passed`。
  - sitemap 規模：`TOTAL=62`、`PRODUCT=14`、`GEO=30`、`GEO_HUB=1`、`BLOG=11`。
- Live 驗收快照（2026-05-13）：
  - `/location/`、30 個 GEO 頁、`/products/`、`/calculator/?product=P001&area=xizhi` 抽測皆 `HTTP 200`。
  - legacy 舊網址抽測維持 `301 -> slug`（樣本：`P001`、`P006`、`P010`、`P013`）。
- Weekly SOP / GSC 快照（2026-05-14）：
  - 7 天、28 天匯入與報表流程可正常執行（含區間不符防呆）。
  - `latest/7d`、`latest/28d` 已有最新 HTML 報表可直接開啟。
  - 已產出首版詞池文件：[12-keyword-pool-v1-2026-05-14.md](./Weekly%20SOP/12-keyword-pool-v1-2026-05-14.md)。
  - KPI 基線採「完整日區間」原則（避免當日未結算資料干擾）：
    - 7 天：`2026-05-06` ~ `2026-05-12`
    - 28 天：`2026-04-15` ~ `2026-05-12`
- 回滾總原則：優先最小回滾（局部 helper/頁面/資料層），若影響面擴大再回退該 Phase 全部改動並重建上傳。

## 已完成事項（里程碑）

- SEO/GEO/Schema Phase 2~7 已完成，且已補 2026-05-13 live 驗收證據。
- GSC KPI 基線已完成：
  - 已有 `7 天` 與 `28 天` query/page/clicks/impressions/CTR/position 基線資料。
  - Weekly SOP 可穩定輸出 `latest/7d`、`latest/28d` 的 query/page HTML 報表。
- 第一版「12 詞池 + 每詞唯一主頁」已完成：
  - 文件：[12-keyword-pool-v1-2026-05-14.md](./Weekly%20SOP/12-keyword-pool-v1-2026-05-14.md)。
  - 原則：以 `產品 + 地區` 為主，先打可進前 10 的中低競爭詞群。
  - 目前詞池與主攻頁已可直接銜接第 2 步（6 頁詞頁優化）。
- 第二版「12 詞池 + 每詞唯一主頁」已完成（已執行並驗收）：
  - 文件：[12-keyword-pool-v2-2026-05-16.md](./Weekly%20SOP/12-keyword-pool-v2-2026-05-16.md)。
  - 對應 6 頁（鋁百葉 / 風琴簾 / 價格指南 / 計算機 / 板橋 / 新莊）已完成詞頁對齊、build/seo:check、FTP 全量上線與 live 驗收。

## 未完成事項

### 排名前10衝刺（進行中）

- 固定 6 頁輪轉優化（持續執行）：
  - 每輪固定 6 頁：`/calculator/`、`/location/sanchong/`、`/location/taipei/`、`/products/roller-blinds/`、`/products/zebra-blinds/`、`/products/wooden-blinds/`。
  - 每輪改寫重點：頁面標題、首屏文案、FAQ、內鏈錨文字一致化，並維持 GEO 導流與估價導流鏈路一致，不新增孤頁。
- 每輪上線與驗收（持續執行）：
  - 固定流程：`npm.cmd run build` -> `npm.cmd run seo:check` -> `out/` 全量 FTP 上傳 -> live 驗收（200、canonical、JSON-LD、sitemap、legacy 301）。
  - `out/` 上傳邊界維持不變：僅網站輸出物，不上傳 `plan.md`、`Phase*.md`、`Weekly SOP` 原始資料、`scripts/`。
- AI 關鍵字推薦 SOP（持續執行）：
  - 每週固定一次：`GSC 匯出 -> AI Prompt 推薦 -> 人工審核 -> 排入下週改版清單`。
  - 每次輸出必含：`新詞推薦`、`舊詞擴寫`、`詞頁對應`、`優先級`、`預估意圖`。
- KPI 驗收門檻（待達成）：
  - 12 詞中至少 4 詞進入前 10。
  - 其餘詞平均排名持續往前（至少較前週改善），並維持 `7 天微調 / 28 天決策` 節奏。

## Phase 文件索引

- [Phase2.md](./Phase2.md) - 狀態：已完成（含部署補登）
- [Phase3.md](./Phase3.md) - 狀態：已完成
- [Phase4.md](./Phase4.md) - 狀態：已完成
- [Phase5.md](./Phase5.md) - 狀態：已完成（2026-05-13 live 補證）
- [Phase6.md](./Phase6.md) - 狀態：已完成（2026-05-13 live 補證）
- [Phase7.md](./Phase7.md) - 狀態：已完成（2026-05-13 Wave A/B 驗收）

## 預定工作（下一步執行序）

1. 先做第 2 步：完成 6 頁詞頁對齊優化（依 12 詞池 V1）
   - `https://online.hong-sen.com/calculator/`
   - `https://online.hong-sen.com/location/sanchong/`
   - `https://online.hong-sen.com/location/taipei/`
   - `https://online.hong-sen.com/products/roller-blinds/`
   - `https://online.hong-sen.com/products/zebra-blinds/`
   - `https://online.hong-sen.com/products/wooden-blinds/`
2. 執行下一批第 3 步：完成 6 頁詞頁對齊優化（依 12 詞池 V2）
   - `https://online.hong-sen.com/products/aluminum-blinds/`
   - `https://online.hong-sen.com/products/honeycomb-blinds/`
   - `https://online.hong-sen.com/blog/curtain-price-guide-2026/`
   - `https://online.hong-sen.com/calculator/`
   - `https://online.hong-sen.com/location/banqiao/`
   - `https://online.hong-sen.com/location/xinzhuang/`
3. 每批 6 頁完成後上線，執行一次 live 驗收（200、canonical、schema、內鏈）。
4. 每批上線後，7 天看 7d 微調、28 天看 28d 判定，更新「保留詞/替換詞/加碼頁」。
5. 目標檢核：每批詞池至少 4 詞進前 10，其餘詞平均排名持續前進。

## 本輪執行紀錄（2026-05-16）

- [x] 6 頁詞頁對齊改寫完成（metadata/H1/FAQ/內鏈）。
- [x] `npm.cmd run build` 成功。
- [x] `npm.cmd run seo:check` 顯示 `SEO check passed`。
- [x] `out/` 全量 FTP 上傳至 `online.hong-sen.com/`（完成上傳 `916` 檔）。
- [x] live 驗收完成（6 目標頁 `HTTP 200`、canonical、JSON-LD、sitemap、legacy 301）。

## 下一批啟動清單（V2）

- [x] 依 [12-keyword-pool-v2-2026-05-16.md](./Weekly%20SOP/12-keyword-pool-v2-2026-05-16.md) 完成第 3 步 6 頁詞頁對齊。
- [x] 完成後執行 `npm.cmd run build` 與 `npm.cmd run seo:check`。
- [x] `out/` 全量 FTP 上傳至 `online.hong-sen.com/`（含 URL encode 路徑重跑，`FAIL=0`）。
- [x] 完成 live 驗收（6 目標頁 200、canonical、JSON-LD、sitemap、legacy 301）。

## 本輪執行紀錄（2026-05-16，V2）

- [x] 6 頁詞頁對齊改寫完成（`/calculator/`、`/location/banqiao/`、`/location/xinzhuang/`、`/products/aluminum-blinds/`、`/products/honeycomb-blinds/`、`/blog/curtain-price-guide-2026/`）。
- [x] `npm.cmd run build` 成功。
- [x] `npm.cmd run seo:check` 顯示 `SEO check passed`。
- [x] `out/` 全量 FTP 上傳至 `online.hong-sen.com/`（`TOTAL=916`、`FAIL=0`）。
- [x] live 驗收完成（6 目標頁 `HTTP 200`、canonical、JSON-LD、sitemap、legacy `P006/P009` 301 正常）。

## 本輪執行紀錄（2026-05-16，固定 6 頁輪轉）

- [x] 固定 6 頁改寫完成（`/calculator/`、`/location/sanchong/`、`/location/taipei/`、`/products/roller-blinds/`、`/products/zebra-blinds/`、`/products/wooden-blinds/`）。
- [x] `npm.cmd run build` 成功。
- [x] `npm.cmd run seo:check` 顯示 `SEO check passed`。
- [x] `out/` 全量 FTP 上傳至 `online.hong-sen.com/`（URL encode 路徑重跑，`TOTAL=916`、`FAIL=0`）。
- [x] live 驗收完成（6 目標頁 `HTTP 200`、canonical、JSON-LD、sitemap 正常）。
- [x] legacy 301 驗收完成（`P005 -> roller-blinds`、`P007 -> wooden-blinds`、`P010 -> zebra-blinds`）。

## 本輪執行紀錄（2026-05-17，估價後台與安全上傳）

- [x] 同網域估價後台骨架上線：`/admin/pricing/login.php`、`/admin/pricing/`、`/admin/pricing/users.php`、`/admin/pricing/logout.php`。
- [x] 前台估價改為呼叫後端 API：`POST /api/calc.php`（前台不再持有公式計算邏輯）。
- [x] 後台介面完成繁體中文化（登入、規則管理、人員管理、提示訊息）。
- [x] 產品顯示補齊中英對照：`P001~P013` 於後台顯示 `英文（中文）`。
- [x] `README.md` 已改為繁體中文版本，並更新部署與後台操作說明。
- [x] 已完成 FTP 上線補檔（`admin/pricing/*`、`api/calc.php`、`private/lib/*`、`private/.htaccess`），並確認端點回應正常。

## GitHub 安全上傳邊界（2026-05-17）

- 敏感檔不上傳 GitHub：
  - `private/users.php`（帳號與密碼雜湊）
  - `private/pricing-rules.php`（實際商業計價規則）
  - `private/runtime/*`、`private/logs/*.log`、`private/backups/*`
- 已更新 `.gitignore` 強化排除規則（含 `*.pid` 與 `private/runtime/*.pid`）。
- GitHub 僅提交「程式碼、後台頁面、API、文件與非敏感設定」。
