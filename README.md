# Curtain Online Price Estimate（窗簾線上估價）

本專案是「Next.js 靜態網站 + PHP 後台/API」的估價系統：

- 前台：產品頁、SEO/GEO 內容、估價頁面（由 Next.js 輸出靜態檔）
- 後台：價格規則管理、使用者管理、備份回滾（PHP）
- API：前台呼叫 `/api/calc.php` 取得估價結果

## 環境需求

- Node.js 20 以上
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

## GitHub 設定方法（重要順序）

以下是 GitHub Pages 使用 GitHub Actions 部署時，建議的設定順序（請依 1 -> 5）：

1. `Repository visibility: Public`（倉庫可見度：公開）
- GitHub Free 的 Pages 一般需公開倉庫才能啟用。

2. `Settings > Pages > Build and deployment > Source: GitHub Actions`（設定 > Pages > 建置與部署 > 來源：GitHub Actions）
- 這一步是告訴 GitHub：網站發布由 workflow 負責，不是 `Deploy from a branch`（由分支直接發布）。

3. `Settings > Actions > General > Actions permissions: Allow all actions and reusable workflows`（設定 > Actions > 一般 > 動作權限：允許所有 actions 與可重用 workflows）
- 若限制過嚴，`actions/checkout`、`actions/deploy-pages` 可能無法執行。

4. `Settings > Actions > General > Workflow permissions: Read and write permissions`（設定 > Actions > 一般 > 工作流程權限：讀寫權限）
- 讓 `GITHUB_TOKEN` 可建立 Pages deployment（Pages 發布記錄）。

5. `Actions > Deploy static content to Pages > Run workflow / Re-run all jobs`（Actions > Deploy static content to Pages > 執行流程 / 重跑所有工作）
- 建議每次修改 `deploy.yml` 後手動重跑一次確認。

若出現：

- `Resource not accessible by integration`（整合權限無法存取資源）
- `Get Pages site failed`（取得 Pages 網站失敗）

請優先檢查上面第 2、3、4 步是否正確。

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
