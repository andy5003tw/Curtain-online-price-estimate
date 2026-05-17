# Curtain Online Price Estimate（窗簾線上估價）

本專案是「Next.js 靜態網站 + PHP 後台/API」的估價系統：

- 前台：產品頁、SEO/GEO 內容、估價頁面（由 Next.js 輸出靜態檔）
- 後台：價格規則管理、使用者管理、備份回滾（PHP）
- API：前台呼叫 `/api/calc.php` 取得估價結果

## 環境需求

- Node.js 22 以上（建議；目前 GitHub Actions workflow 使用 Node 22）
- npm（Windows 可使用 `npm.cmd`）
- 可執行 PHP 的主機環境（建議 PHP 8.x）

## 專案結構（重點）

- `src/`：Next.js 前台原始碼
- `out/`：`npm.cmd run build` 後的靜態輸出（可直接部署）
- `api/`：估價 API（PHP）
- `admin/pricing/`：後台頁面（PHP）
- `private/`：規則、帳號、記錄與函式庫（有 `.htaccess` 保護）
- `Weekly SOP/`：每週 SOP 與報表流程資料

## 本機開發（前台）

1. 安裝套件

```bash
npm.cmd install
```

2. 啟動開發伺服器

```bash
npm.cmd run dev
```

3. 開啟瀏覽器

- `http://localhost:3000`

## 建置與匯出（靜態）

```bash
npm.cmd run build
```

- 產出目錄：`out/`
- 本專案 `next.config.ts` 設定為 `output: "export"`，部署時以 `out/` 內容為準

## SEO 檢查

- 快速檢查

```bash
npm.cmd run seo:check
```

- 匯出後預檢

```bash
npm.cmd run seo:preflight
```

## GitHub Pages 設定與部署重點（GitHub Actions）

本專案使用 `.github/workflows/deploy.yml` 自動部署，請按以下順序設定：

1. `Repository visibility: Public`（倉庫可見度：公開）
- GitHub Free 方案下，Pages 一般需公開倉庫才可啟用。

2. `Settings > Pages > Build and deployment > Source: GitHub Actions`
- 必須選 `GitHub Actions`，不要選 `Deploy from a branch`。

3. `Settings > Actions > General > Actions permissions`
- 建議選 `Allow all actions and reusable workflows`。

4. `Settings > Actions > General > Workflow permissions`
- 必須選 `Read and write permissions`（讓 `GITHUB_TOKEN` 可建立 Pages deployment）。

5. 手動觸發部署
- 路徑：`Actions > Deploy static content to Pages`。
- 點進工作流程頁後，右上角可按 `Run workflow`（分支選 `main`）。
- 若已跑過一版，進入該次執行頁可用 `Re-run all jobs`。

6. 若看不到 `Run workflow`，請依序檢查
- 是否已點進特定 workflow 頁（不是 Actions 總覽）。
- Actions 是否被關閉。
- 目前帳號是否有寫入權限。
- `.github/workflows/deploy.yml` 是否在 `main` 分支。

7. 若你剛切換過公開/私有
- 需重新跑一次 workflow；否則常見 `404 There isn't a GitHub Pages site here`。

### 目前 workflow 版本（2026-05）

- `actions/checkout@v6`
- `actions/setup-node@v6`（`node-version: 22`）
- `actions/configure-pages@v6`
- `actions/upload-pages-artifact@v5`
- `actions/deploy-pages@v5`
- 並設定 `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24=true`（因應 Node 20 淘汰過渡期）

### 常見錯誤快速排查

- `Resource not accessible by integration`
- `Get Pages site failed`
- `There isn't a GitHub Pages site here`

請先回頭檢查本段第 2、3、4、7 點。

## GitHub Pages 限制（本專案）

- GitHub Pages 是靜態主機，不支援 PHP。
- 本專案估價 API 為 `POST /api/calc.php`（PHP），因此 GitHub Pages 上僅能當前台展示。
- 真正可計算版本請使用正式站：`https://online.hong-sen.com/calculator/`

## README 更新紀錄（部署段落整理）

- 已合併原本重複的 Pages 設定描述為單一章節。
- 已補上 `Run workflow` 實際路徑與找不到按鈕時的檢查清單。
- 已補上 Node 20 淘汰後的 workflow 版本與 Node 24 過渡設定。
- 已補上「GitHub Pages 不支援 PHP」限制，避免誤判為前端故障。

## 部署說明

### 1) 前台靜態檔

- 請上傳 `out/` 內「所有內容」到網站根目錄
- 不要把 `out` 資料夾整層再包一層上傳

### 2) 後台與 API（PHP）

除了前台靜態檔，還要部署以下目錄：

- `api/`
- `admin/pricing/`
- `private/`

`private/.htaccess` 需保留，避免規則與帳號資料被外部直接讀取。

## 估價 API（公開給前台呼叫）

- `POST /api/calc.php`
- Request（JSON）：
  - `product_id`
  - `width_cm`
  - `height_cm`
  - `area_id`（可選）
- Response：
  - 成功：`{ ok: true, data: { material_cost, install_cost, total_price } }`
  - 失敗：`{ ok: false, error_code, message }`

## 後台入口與功能

- 登入頁：`/admin/pricing/login.php`
- 後台首頁：`/admin/pricing/`
- 人員管理（owner）：`/admin/pricing/users.php`
- 登出（POST）：`/admin/pricing/logout.php`

首次部署且尚無帳號時，登入頁會先引導建立 owner 帳號。

## 後台權限角色

- `owner`：可管理人員、回滾規則、修改價格
- `admin`：可修改價格
- `editor`：可修改價格（不含人員管理與回滾）

## 後台資料與記錄

- 價格規則：`private/pricing-rules.php`
- 使用者：`private/users.php`
- 備份：`private/backups/pricing-rules-*.php`
- 稽核紀錄：`private/logs/audit-YYYY-MM.log`

## Weekly SOP

- 主要資料夾：`Weekly SOP/`
- 最新報表快照：`Weekly SOP/latest/`
- 歷史報表封存：`Weekly SOP/reports/`
