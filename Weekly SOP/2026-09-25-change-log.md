# 2026-09-25 變更紀錄：全站導覽頁 UX 與服務地點 Banner 對齊

## 範圍

- 前端頁面：`/products/`、`/cases/`、`/blog/`、`/calculator/`、`/location/`、`/location/taipei/`、`/location/new-taipei/`。
- 共用元件與樣式：`src/components/EditorialLandingHero.tsx`、`src/app/globals.css`。
- 本輪不變更 canonical、metadata、JSON-LD、sitemap、keyword owner 或既有 SEO/GEO lifecycle receipt。

## 產品、案例、文章與試算頁

- Products：選款導讀置中，8 個快速入口重組為兩張各 4 項的卡片；連結與五個 FAQ 加入一致的 Lucide 圖示，三個分類標題置中。價格指南次要 CTA 的普通狀態文字改淺，Hover 時才加深。
- Cases：客廳案例導讀置中且保留左右閱讀留白；連結重組為 3 張卡並加入小圖示。五個施工案例 FAQ 採可展開卡片並為每題加入主題圖示。
- Blog：所有文章連結拆為「挑選與材質指南」及「價格、保養與安裝指南」兩張卡；每篇文章依分類顯示小圖示。
- Calculator：相關閱讀入口整理為 3 張卡，加入連結圖示；試算前重點及常見問題改為有圖示的資訊卡。FAQ 每題只保留一個主題圖示。

## 服務地點與共用 Banner

- `/location/` 的台北／新北城市區塊移除重複的城市標題橫幅，保留圖左、城市資訊與 CTA 右側的整合卡。兩張整合卡底色使用 banana 米色 `#f4eee5`，咖啡色只用於外框、重點與主按鈕。
- 手機服務地點快速入口可換行，台北與新北按鈕各自置中。
- `/location/taipei/` 和 `/location/new-taipei/` 改用 `EditorialLandingHero`。與六個主導航頁共享桌機 31rem、手機 37rem Banner、高度 3rem 的 CTA、圖片裁切與內容寬度。
- 主 CTA 新增透明 1px 外框，和次要 CTA 的外框尺寸一致；兩者使用相同陰影範圍，修正視覺高度與文字基線不一致。

## 驗證

- `npm.cmd run build`：通過，81 個靜態頁。
- `npm.cmd run seo:check`：通過。
- `npm.cmd run seo:preflight`：通過。
- `node .agents/skills/curtain-online-seo-geo/scripts/keyword-owner-check.mjs`：通過，14 rows／87 unique normalized keywords。
- 桌機與手機檢查：雙北城市卡、快速入口、共用 Hero CTA、產品與案例 FAQ、文章與試算連結卡均正常。

## 正式部署與驗收

- FTP quick dry run：從 `out/` 選取 1,229 個網站產物。
- 正式 FTP quick deploy：selected=1,229、uploaded=179、skipped=1,050、failed=0、uploadedMB=15.21。
- 部署 manifest：`Weekly SOP/latest/seo-geo-deployment-manifest.json`。
- 部署範圍僅為 `out/`，未包含 Markdown、原始碼、`download/`、`source/`、`private/` 或正式價格規則檔。
- 正式站回讀確認 `/location/`、`/location/taipei/`、`/location/new-taipei/` 的 Banner、CTA、城市專頁連結及估價 URL 正常；本次同時上傳的 Products、Cases、Blog、Calculator 等靜態頁產物亦完成同步。

## 相關文件

- 價格後台公式設定與新增試算產品功能的權限、資料欄位、測試及 2026-09-24 上線紀錄，維護於根目錄 `PRICING_FORMULA_ADMIN.md`；本次未重複記載。
- 完整交接狀態與後續維護注意事項，維護於根目錄 `HANDOVER.md` 第十三節。

## 2026-09-25 FAQ 與服務區導覽主題 icon 強化（已部署並完成正式站驗收）

### 變更範圍

- `/` 首頁 FAQ 五個問題：加入依問題主題選擇的 Lucide icon，包含材質、挑選、丈量、估價與服務流程等意象。
- `/about/` 關於我們 FAQ 七組問答：加入大型主題 icon，桌機與手機版皆保留清楚的圖示辨識度。
- `/location/taipei/`：將「熱門窗型價格試算與深入推薦」連結整理為三張卡片，並在推薦連結、FAQ 問題與鄰近服務區域前加入對應 icon。
- `/location/new-taipei/`：沿用地區頁共用模板，在 FAQ 問題與三張鄰近服務區域卡片前加入對應 icon。
- `/location/`：四個生活圈標題加入主題 icon，並使用不同顏色區分生活圈：
  - 台北都會核心圈：`Building2`，`#b45309`
  - 台北景觀與文教生活圈：`GraduationCap`，`#4f46e5`
  - 新北核心大城與捷運生活圈：`TrainFront`，`#0f766e`
  - 新北延伸與景觀生活圈：`Mountain`，`#0284c7`
- `/location/` 生活圈標題 icon 已由 23px 放大至 30px，並調整與標題文字的間距；既有 icon 配色維持不變。

### 實作檔案與 SEO 邊界

- 修改 `src/app/page.tsx`、`src/app/about/page.tsx`、`src/app/location/page.tsx`、`src/app/location/[area]/page.tsx` 與 `src/app/globals.css`。
- 保留既有 FAQ 文案、連結 URL、canonical、metadata、JSON-LD、sitemap、keyword owner 與 SEO/GEO lifecycle receipt；本輪未新增或修改結構化資料。

### 本機驗證與部署狀態

- `npm.cmd run build -- --webpack`：通過，81 個靜態頁成功匯出；預設 Turbopack 建置曾因 Windows `.next` 快取檔存取被拒而中止，改用 Webpack 建置完成驗證。
- `npm.cmd run seo:check`：通過。
- `node .agents/skills/curtain-online-seo-geo/scripts/keyword-owner-check.mjs`：通過，14 rows／87 unique normalized keywords。
- 目標頁 ESLint：0 errors；保留既有 2 個 `<img>` 效能 warning。
- FTP quick deploy：selected=1,248、uploaded=426、skipped=822、failed=0、uploadedMB=24.85；部署 manifest 為 `Weekly SOP/latest/seo-geo-deployment-manifest.json`。
- 部署範圍僅為 `out/` 靜態網站產物，未上傳 Markdown、原始碼、`download/`、`source/` 或其他本機工作文件。
- 正式站回讀通過：`/`、`/about/`、`/location/`、`/location/taipei/`、`/location/new-taipei/` 均 HTTP 200，canonical 正確；首頁 FAQ、About FAQ、生活圈標題 icon、台北推薦卡與雙北地區 FAQ／鄰近服務 icon 均確認存在。
- `https://online.hong-sen.com/sitemap.xml` HTTP 200，包含 `/location/`、`/location/taipei/` 與 `/location/new-taipei/`；五個驗收頁的 JSON-LD 均可解析。
- 預設 Turbopack 建置因 Windows `.next` 快取檔存取被拒而中止，本次以同版本 Webpack fallback 完成 81 頁建置後部署；Git commit 尚未建立。
