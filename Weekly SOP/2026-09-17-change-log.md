# 2026-09-17 變更紀錄：AI Banner 與 About 優勢卡

## 範圍

- 本機前端 UX 改版：`/location/taipei/`、`/location/new-taipei/`、`/about/`、`/products/`、`/cases/`、`/blog/`、`/calculator/`。
- 本輪不變更 canonical、metadata、JSON-LD、sitemap、keyword owner、GSC queue 或 SEO/GEO lifecycle receipt。

## AI 圖片與備份

- 市級服務頁：4 張 AI Hero（台北／新北各桌機、手機）已存至 `public/location_img/city-hero/`，並備份至 `download/city-hero/`。
- 主導航五頁：10 張 AI Hero（每頁桌機、手機各一）已存至 `public/nav-hero/`，並備份至 `download/nav-hero/`。
- 圖片皆要求無文字、無 Logo、無浮水印；台北採冷灰藍都會感、新北採暖沙金住宅感，五個主導航頁依功能採不同室內情境。

## 版面與互動

- 新增 `src/components/EditorialLandingHero.tsx`，五個主導航頁改為短 H1、短說明與主／輔 CTA；原長文與快速連結下移為導讀區。
- H1 仍維持單一語意標題，樣式對齊 `/location/`：`clamp(2rem, 3.2vw, 3rem)`、800 字重、`line-height: 1.25`。桌機文案上移，CTA 下移；手機版採自然堆疊。
- Products 與 Calculator 的品項選單移至 Banner 下方；Cases、Blog、Calculator 的 CTA 已連至既有篩選器、文章起點與試算／說明錨點。
- About 首段右側施工圖組頂緣對齊左側文字；三項優勢重構為三欄卡片，搭配 Calculator、ShieldCheck、Clock 圖示。卡片結構參考 `D:\projects\168wallpaper\resources\views\front\about.blade.php`，未複製其品牌素材或 CSS。
- 市級頁手機 Hero 再調整：台北冷灰藍與新北暖沙金各重新生成一張斜角室內取景；壓縮後實際使用 `public/location_img/city-hero/taipei-mobile-angle-v2.webp` 與 `new-taipei-mobile-angle-v2.webp`。手機兩顆 CTA 取消直向堆疊，改為左右等寬同列，並以 `margin-top: auto` 固定推至 Hero 圖底部；PNG 版本備份於 `download/city-hero/`，未覆蓋先前備份。

## 圖片壓縮交接

- 使用者後續將壓縮圖片放入 `source/nav-hero/`，並通知 AI。
- 需沿用 `about|products|cases|blog|calculator` + `-desktop|-mobile` basename；可以 WebP、JPG 或 PNG。
- AI 僅可替換 `public/nav-hero/` 的網站版本；`download/nav-hero/` 原始 PNG 不可覆蓋。

### 已完成的壓縮置換（2026-09-17）

- 已核對使用者提供的 `source/nav-hero-20260917/`（10 張）與 `source/city-hero-20260917/`（4 張）WebP：桌機皆為 1672×941，手機皆為 941×1672，壓縮報告顯示檔案縮減約 97%。
- 10 張主導航圖已複製至 `public/nav-hero/` 並更新五個頁面引用為 `.webp`。
- 4 張市級圖已複製至 `public/location_img/city-hero/`；`src/app/location/[area]/page.tsx` 與 city data 已改用 WebP，手機採兩張斜角版本。
- `download/` PNG 高品質備份未修改。已通過 build、SEO check、SEO preflight 與輸出 HTML 引用確認；本輪仍尚未 FTP 部署。

## 驗證與部署狀態

- 已通過：`npm.cmd run build`、`npm.cmd run seo:check`、本機瀏覽器 Accessibility／CTA／錨點檢查。
- 未執行 FTP 部署、正式站驗收或 Git commit。部署前必須再次完成 build、SEO check 與響應式畫面檢查。

## 部署嘗試紀錄（2026-09-17）

- 部署前重新通過：`npm.cmd run build`（81 頁）、`npm.cmd run seo:check`、`npm.cmd run seo:preflight`、`npm.cmd run deploy:ftp:dry`。
- dry run：quick 模式以 `out/` 為唯一上傳根目錄，選取 487 個網站產物；`download/`、`source/` 與本文件均未納入部署範圍。
- 正式 `npm.cmd run deploy:ftp` 失敗：遠端 FTP 在 `GetRequestStream` 建立連線時持續回傳 `Unable to connect to the remote server`。前 14 個檔案沒有任何成功上傳，已停止程序，以避免 487 次無效重試與不完整部署。
- 結論：本輪 UI 仍為本機待部署狀態，尚不可標示為正式站已更新或進行 Live verification。待 FTP 恢復後，依序重跑 dry run、正式 quick deploy、正式站驗收；不需重建圖片備份。

### 第二次部署嘗試（WebP 置換後）

- 已再通過 `npm.cmd run build`、`npm.cmd run seo:check`、`npm.cmd run seo:preflight`，quick dry run 選取 487 個 `out/` 網站產物且 failed=0。
- 正式 quick deploy 仍無法建立 FTP 上傳連線；前 6 個檔案均在 `GetRequestStream` 回傳 `Unable to connect to the remote server`，已手動中止，uploaded=0、未進行 Live verification。
- 結論不變：正式站未更新；待 FTP 主機恢復後再重跑 dry run、quick deploy 與正式站驗收。

## 成功部署與正式站驗收（2026-09-17）

- 後續診斷確認先前錯誤不是 FTP 遠端或帳密問題，而是受限沙盒禁止對外 TCP；在可連網的非沙盒環境，`ftp.hong-sen.com:21` 與 `online.hong-sen.com:443` 均可連線。
- 使用既有 `npm.cmd run deploy:ftp` quick 流程完成上傳：selected=487、uploaded=100、skipped=387、failed=0、uploadedMB=10。manifest：`Weekly SOP/latest/seo-geo-deployment-manifest.json`；部署範圍仍只有 `out/`，未包含 `download/`、`source/` 或文件。
- 正式站驗收通過：About、Products、Cases、Blog、Calculator、Taipei、New Taipei 均為 HTTP 200，含正確 canonical、JSON-LD、對應 WebP Hero 與實際 CTA 文案；sitemap 含兩個市級 URL。台北／新北頁另確認手機斜角 WebP 與「線上價格試算」CTA 已生效。
- Git commit 未建立；本文件與 `HANDOVER.md`、`plan.md` 已更新作為後續交接依據。

## Hero WebP 漏傳修正（2026-09-17）

- 使用者回報 `/about/` Hero 圖未顯示。檢查後確認 HTML 的 WebP 路徑正確，但 quick deploy 的檔案白名單不包含一般 public 圖片；因此第一輪的 HTML 已上線、14 張 Hero WebP 未隨之上傳。
- 以 `scripts/deploy-ftp.ps1 -Mode paths -Force` 僅補傳 `nav-hero/*.webp`（10 張）及 `location_img/city-hero/*.webp`（4 張）：selected=14、uploaded=14、skipped=0、failed=0、uploadedMB=0.75。
- manifest：`Weekly SOP/latest/2026-09-17-hero-webp-hotfix-deployment-manifest.json`。逐張 HTTP GET 回讀確認 14 張全為 200、`image/webp`、bytes > 0；About HTML 亦確認引用 `nav-hero/about-desktop.webp`。未將 PNG 備份、`download/`、`source/` 或文件部署。

## Quick 部署靜態資產規則修復（2026-09-17）

- 已修正 `scripts/deploy-ftp.ps1`，使 quick 模式自動納入一般 public 圖片與字型（`avif/gif/ico/jpg/jpeg/png/svg/webp/woff/woff2/ttf/otf`），避免日後只更新 HTML 而遺漏被引用的背景圖或字型。
- 不連網 quick dry run 已確認選取 1,245 個 `out/` 網站產物，並驗證 14/14 本輪 Hero WebP 都會納入；本次僅修正未來部署選檔邏輯，未重複上傳已成功的圖片。
