# 2026-09-24 變更紀錄：SEO/GEO Round 1、正式上線與自動流程修復

## 執行範圍與設計決策

- Mode 為 monthly：以 28d 作策略判斷，7d 作異常監控；本次只執行既有 Round 1，沒有重新選頁、選詞或建立其他 Round。
- Queue：`seo-geo-a4151d46f72664bd`；Cycle：`seo-geo-v2-a4151d46f72664bd43e3c935`。
- 兩個 owner page：P007 `/products/wooden-blinds/`、P001 `/products/custom-curtains/`。保留既有 owner 關係，不讓產品頁搶其他 owner 詞。
- Action-plan owner keywords 原樣沿用：P007「實木百葉窗價格試算／木百葉窗簾價格／台北實木百葉窗價格／三重實木百葉窗價格／實木百葉窗價格試算／木百葉窗簾訂製／書房窗簾」；P001「窗簾訂製價格／做窗簾價格／訂製窗簾價格／窗簾訂做價格／遮光窗簾／布簾訂製／客廳布簾」。
- 內容設計聚焦價格試算、材質／適用情境與明確估價 CTA。P001 同步可見 FAQ 與 FAQ JSON-LD；P007 保留已合規的 FAQ／Schema，只調整 SEO 摘要與相關內鏈錨文字。
- 未修改公開 API、型別、後台或計價邏輯；未直接修改 `out/`。

## Round 1 內容變更

### P001：窗簾訂製價格

- 更新產品描述、title 與 meta description，涵蓋窗簾訂製價格、做窗簾價格、訂製窗簾價格、窗簾訂做價格、遮光窗簾、布簾訂製及客廳布簾。
- 調整首屏短答案，讓使用者先按尺寸、布料、遮光等級、軌道與安裝條件估算，再由到府丈量確認正式報價。
- 更新相關 FAQ 問題與答案，並維持可見 FAQ 與 JSON-LD parity；內鏈錨文字改為對應價格指南、估價工具及產品 owner 的用語。

### P007：實木百葉窗價格試算

- 更新 title 與 meta description，強化實木百葉窗價格試算、木百葉窗簾價格、客廳／書房與線上估價訊息。
- 內鏈錨文字改為明確指向台北、三重及木百葉價格指南；FAQ／Schema 維持既有合規內容。

## Source 與 registry

- `src/data/products.ts`：更新 P001 的描述、SEO title／description／owner keywords，以及 P007 SEO title／description。
- `src/app/products/[slug]/page.tsx`：更新 P001 首屏短答案、FAQ 與相關內鏈文案；更新 P007 相關內鏈錨文字。
- `Weekly SOP/config/target-registry.json`：更新 P001、P007 的 `lastChangedAt` 與 registry `updatedAt` 為 `2026-09-24`。

## 本機驗證

以下 Round 1 驗證均通過，並建立 queue-bound validation receipt：

- `node .agents/skills/curtain-online-seo-geo/scripts/keyword-owner-check.mjs`
- `npm.cmd run build`
- `npm.cmd run seo:check`
- `npm.cmd run seo:preflight`

## 正式部署與 live verification

- FTP 部署時間：`2026-09-24T07:58:42Z`；模式為 queue-bound `paths`、`dry_run=false`。
- Deployment manifest：`Weekly SOP/latest/seo-geo-deployment-manifest.json`；selected=25、uploaded=5、skipped=20、failed=0（363,736 bytes）。兩個目標頁 HTML 均已上傳。
- Live verification 時間：`2026-09-24T08:09:13Z`；manifest：`Weekly SOP/latest/seo-geo-live-verification.json`，status=`passed`，scope=`queue_targets`，與本 queue/cycle/action IDs 綁定。
- 兩個目標頁皆 HTTP 200；title、meta description、H1、canonical、FAQ parity、JSON-LD、內鏈、CTA、robots、sitemap 檢查通過。`robots.txt` 與 sitemap 均 HTTP 200，sitemap 有 63 個 URL；P001、P007 舊產品路徑均以 301 轉至正確 owner URL。
- Lifecycle receipt 已依序到 `live_verified`（`2026-09-24T08:10:35Z`）；effective workflow consistency=`valid`。

## 自動部署錯誤與程式修復

- 2026-09-24 自動部署協調器已完成 preflight、dry-run 與 FTP 上傳，但在呼叫 lifecycle PowerShell 腳本後讀取尚未設定的 `$LASTEXITCODE`，因此 journal 將該次自動流程記為 failed（`current_stage=ftp_deploy`），HTA 顯示「自動部署未完成」。這不是 FTP 上傳失敗；該次協調流程在 lifecycle 回報處提前中止，未在同一次自動流程中執行 live verification。
- `scripts/invoke-seo-geo-autodeploy.ps1` 現以 `pwsh.exe` 子程序執行 lifecycle 與 live verification 腳本，並檢查子程序的實際 exit code；失敗輸出會附在錯誤訊息中。成功完成每個子步驟後才追加相應 journal stage。
- 原自動部署 journal 保留作為該次執行的歷史紀錄，不手動改寫成 completed。之後已獨立完成 live verification 與 `live_verified` receipt；因 lifecycle 已在 `live_verified`，沒有重跑上傳。自動部署修復尚未在另一個可部署 Round 上實際跑過完整 Execute 流程。

## 當日 GSC 與 AI 可見度記錄

- GSC 7d／28d baseline 均 decision-ready，資料截至 `2026-09-21`。這些是本輪部署前的資料窗口，尚不能作為部署後 7d lifecycle evidence。
- GSC Search Generative AI Excel 期間為 `2026-09-15`～`2026-09-21`：曝光 60，台灣 59（98.33%）。這只代表 GSC 生成式 AI 功能的曝光分布，不推論 direct AI engine 的品牌提及、引用或正確性。
- 當日 direct AI observation 的正式 baseline 仍是 `gpt-5.4-mini`；使用者提供的 UI 顯示品牌題提及 2/2、引用 1/2，非品牌題提及／引用均 0/4，總提及 2/6、引用 1/6，accuracy 尚無人工審核。`gpt-5.6-luna` 對照報告獨立保存，baseline mini 結果未覆蓋；本日未作預設模型切換決定，也未依尚未審閱的 comparison report 判定 Luna 優劣。

## 下一步

- 等待 Search Console 結算完整日期；更新後的 decision-ready 7d manifest `end_date` 至少須涵蓋 `2026-10-01`。更新 GSC 並重建行動報告後，才記錄 `observing_7d` lifecycle receipt。
- 後續 28d 成效判讀仍需依部署後完整資料窗口與 28d decision-ready manifest；不以目前截至 `2026-09-21` 的資料宣稱本輪成效。
