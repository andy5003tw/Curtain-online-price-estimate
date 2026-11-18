<?php
declare(strict_types=1);

require_once dirname(__DIR__, 2) . '/private/lib/storage.php';
require_once dirname(__DIR__, 2) . '/private/lib/auth.php';
require_once dirname(__DIR__, 2) . '/private/lib/audit.php';
require_once dirname(__DIR__, 2) . '/private/lib/calc_engine.php';
require_once __DIR__ . '/_fields.php';

hs_bootstrap_session();
hs_require_login();

$productId = strtoupper(trim((string) ($_POST['product_id'] ?? $_GET['product_id'] ?? '')));
$rules = hs_read_rules();
$product = $rules['products'][$productId] ?? null;
if (!is_array($product) || hs_formula_definition((string) ($product['formula_type'] ?? '')) === null) {
    http_response_code(404);
    echo '找不到產品。';
    exit;
}
$type = (string) $product['formula_type'];
$pricing = is_array($product['pricing'] ?? null) ? $product['pricing'] : [];
$currentSettings = hs_effective_formula_settings($type, $pricing, is_array($product['formula_settings'] ?? null) ? $product['formula_settings'] : []);
$formSettings = $currentSettings;
$error = null;
$preview = null;
$customWidth = 150.0;
$customHeight = 150.0;
$revision = hs_rules_revision();
$canManage = hs_can_manage_formula();

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!hs_verify_csrf($_POST['csrf_token'] ?? null)) {
        $error = '表單驗證失敗，請重新載入頁面。';
    } elseif (!$canManage) {
        http_response_code(403);
        $error = '你沒有修改公式的權限。';
    } else {
        $action = (string) ($_POST['action'] ?? '');
        if ($action === 'preview') {
            unset($_SESSION['formula_preview_' . $productId]);
            $validated = hs_validate_formula_settings($type, $_POST);
            $rawWidth = $_POST['width_cm'] ?? null;
            $rawHeight = $_POST['height_cm'] ?? null;
            if (!$validated['ok']) {
                $error = $validated['message'];
            } elseif (!is_scalar($rawWidth) || !is_scalar($rawHeight) || !is_numeric($rawWidth) || !is_numeric($rawHeight)
                || (float) $rawWidth <= 0 || (float) $rawHeight <= 0 || (float) $rawWidth > 10000 || (float) $rawHeight > 10000) {
                $error = '試算寬高須介於 0 至 10000 cm。';
            } elseif (!hs_preview_quotes_are_valid($type, $pricing, $validated['settings'], (float) $rawWidth, (float) $rawHeight)) {
                $error = '參數會產生無效或過大的報價，請調整後重新預覽。';
            } else {
                $formSettings = $validated['settings'];
                $customWidth = (float) $rawWidth;
                $customHeight = (float) $rawHeight;
                $preview = $formSettings;
                $_SESSION['formula_preview_' . $productId] = [
                    'revision' => $revision,
                    'settings' => $formSettings,
                    'width' => $customWidth,
                    'height' => $customHeight,
                ];
            }
        } elseif (in_array($action, ['save', 'publish', 'unpublish'], true)) {
            $pending = $_SESSION['formula_preview_' . $productId] ?? null;
            if ($action !== 'unpublish' && (!is_array($pending) || ($pending['revision'] ?? '') !== $revision)) {
                $error = '規則已更新或尚未完成預覽，請重新試算。';
            } elseif ($action === 'publish' && ($pending['settings'] ?? null) !== $currentSettings) {
                $error = '請先儲存預覽的公式參數，再重新試算後上架。';
            } else {
                $outcome = hs_with_lock('pricing-rules', function () use ($productId, $action, $pending, $revision) {
                    if (hs_rules_revision() !== $revision) {
                        return ['ok' => false, 'message' => '其他人已更新規則，請重新載入並試算。'];
                    }
                    $latest = hs_read_rules();
                    $item = $latest['products'][$productId] ?? null;
                    if (!is_array($item)) {
                        return ['ok' => false, 'message' => '找不到產品。'];
                    }
                    if ($action !== 'save' && !isset($item['display_name'])) {
                        return ['ok' => false, 'message' => '既有產品介紹頁的品項不能在此下架。'];
                    }
                    if ($action === 'save') {
                        $settings = $pending['settings'];
                        $item['formula_settings'] = $settings;
                        $item['pricing'] = hs_sync_legacy_formula_fields($item['pricing'], $settings);
                    } else {
                        $item['status'] = $action === 'publish' ? 'active' : 'inactive';
                    }
                    if ($action === 'publish') {
                        if (!hs_preview_quotes_are_valid($item['formula_type'], $item['pricing'], $item['formula_settings'] ?? [], 150, 150)) {
                            return ['ok' => false, 'message' => '公式產生無效報價，無法上架。'];
                        }
                        $quote = hs_calc_price($item['formula_type'], 150, 150, $item['pricing'], $item['formula_settings'] ?? []);
                        if ($quote['total_price'] <= 0) {
                            return ['ok' => false, 'message' => '試算金額須大於零才能上架。'];
                        }
                    }
                    $backup = hs_backup_rules();
                    if ($backup === null) {
                        return ['ok' => false, 'message' => '建立備份失敗。'];
                    }
                    $latest['products'][$productId] = $item;
                    $latest['updated_at'] = hs_now_iso();
                    $latest['version'] = hs_next_rules_version();
                    if (!hs_save_rules($latest)) {
                        return ['ok' => false, 'message' => '儲存失敗。'];
                    }
                    return ['ok' => true, 'backup' => basename($backup)];
                });
                if ($outcome['ok']) {
                    hs_audit_log('formula_' . $action, ['product_id' => $productId, 'backup_file' => $outcome['backup']]);
                    unset($_SESSION['formula_preview_' . $productId]);
                    hs_set_flash('success', $action === 'save' ? '公式設定已儲存。' : ($action === 'publish' ? '產品已上架。' : '產品已下架。'));
                    header('Location: /admin/pricing/formula.php?product_id=' . rawurlencode($productId));
                    exit;
                }
                $error = $outcome['message'];
            }
        }
    }
}

$flash = hs_get_flash();
$definition = hs_formula_definition($type);
$status = hs_product_status($product);
?>
<!doctype html>
<html lang="zh-Hant"><head><meta charset="utf-8" /><meta name="viewport" content="width=device-width, initial-scale=1" />
<title>公式設定－<?= hs_admin_h(hs_product_display_name($productId, $product)) ?></title><?php hs_admin_page_style(); ?></head>
<body><main>
  <p><a href="/admin/pricing/">← 返回價格規則後台</a></p>
  <section class="panel">
    <h1><?= hs_admin_h($productId) ?>　<?= hs_admin_h(hs_product_display_name($productId, $product)) ?>－公式設定</h1>
    <p class="muted">公式：<?= hs_admin_h($definition['label']) ?>　｜　狀態：<?= hs_admin_h($status) ?></p>
    <p><?= hs_admin_h($definition['steps']) ?></p>
    <p class="muted">1 尺＝30.3 cm；1 碼＝3 尺。單價請回價格後台調整。</p>
  </section>
  <?php if ($flash): ?><div class="message <?= hs_admin_h($flash['type']) ?>"><?= hs_admin_h($flash['message']) ?></div><?php endif; ?>
  <?php if ($error): ?><div class="message error"><?= hs_admin_h($error) ?></div><?php endif; ?>
  <section class="panel">
    <h2>參數與試算</h2>
    <form method="post" id="formula-preview-form">
      <input type="hidden" name="csrf_token" value="<?= hs_admin_h(hs_csrf_token()) ?>" />
      <input type="hidden" name="product_id" value="<?= hs_admin_h($productId) ?>" />
      <input type="hidden" name="action" value="preview" />
      <div class="grid"><?php hs_render_formula_fields($type, $formSettings, !$canManage); ?></div>
      <?php if ($canManage): ?>
        <h2 style="margin-top:22px">自訂尺寸</h2>
        <div class="grid">
          <div class="field"><label for="width_cm">寬度（cm）</label><input id="width_cm" name="width_cm" type="number" min="0.01" max="10000" step="0.01" required value="<?= hs_admin_h($customWidth) ?>" /></div>
          <div class="field"><label for="height_cm">高度（cm）</label><input id="height_cm" name="height_cm" type="number" min="0.01" max="10000" step="0.01" required value="<?= hs_admin_h($customHeight) ?>" /></div>
        </div>
        <div class="actions"><button type="submit">預覽修改前後報價</button></div>
      <?php endif; ?>
    </form>
  </section>
  <?php if ($preview !== null): ?>
    <section class="panel"><h2>試算比較</h2>
      <?php hs_render_preview_table($type, $pricing, $currentSettings, $pricing, $preview, $customWidth, $customHeight); ?>
      <p class="muted">修改欄位後，請重新預覽才儲存。</p>
      <form method="post" class="actions" id="formula-save-form">
        <input type="hidden" name="csrf_token" value="<?= hs_admin_h(hs_csrf_token()) ?>" />
        <input type="hidden" name="product_id" value="<?= hs_admin_h($productId) ?>" />
        <button type="submit" name="action" value="save">儲存預覽的公式設定</button>
        <?php if ($status !== 'active' && $preview === $currentSettings): ?><button type="submit" name="action" value="publish">上架產品</button><?php endif; ?>
      </form>
    </section>
  <?php endif; ?>
  <?php if ($canManage && $status === 'active' && isset($product['status'])): ?>
    <section class="panel"><h2>產品狀態</h2><p>下架後，訪客無法選擇或試算此產品；資料會保留。</p>
      <form method="post" class="actions">
        <input type="hidden" name="csrf_token" value="<?= hs_admin_h(hs_csrf_token()) ?>" />
        <input type="hidden" name="product_id" value="<?= hs_admin_h($productId) ?>" />
        <button class="danger" type="submit" name="action" value="unpublish">下架產品</button>
      </form>
    </section>
  <?php endif; ?>
  <script>
    const previewForm = document.getElementById('formula-preview-form');
    const saveForm = document.getElementById('formula-save-form');
    if (previewForm && saveForm) {
      const requireNewPreview = () => {
        saveForm.querySelectorAll('button').forEach(button => {
          button.disabled = true;
          button.title = '參數已修改，請重新預覽';
        });
      };
      previewForm.addEventListener('input', requireNewPreview);
      previewForm.addEventListener('change', requireNewPreview);
    }
  </script>
</main></body></html>
