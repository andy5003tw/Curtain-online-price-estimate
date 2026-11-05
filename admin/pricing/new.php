<?php
declare(strict_types=1);

require_once dirname(__DIR__, 2) . '/private/lib/storage.php';
require_once dirname(__DIR__, 2) . '/private/lib/auth.php';
require_once dirname(__DIR__, 2) . '/private/lib/audit.php';
require_once dirname(__DIR__, 2) . '/private/lib/calc_engine.php';
require_once __DIR__ . '/_fields.php';

hs_bootstrap_session();
hs_require_login();
if (!hs_can_manage_formula()) {
    http_response_code(403);
    echo '你沒有新增產品的權限。';
    exit;
}

$definitions = hs_formula_definitions();
$type = (string) ($_POST['formula_type'] ?? $_GET['formula_type'] ?? 'standard_track');
if (!isset($definitions[$type])) {
    $type = 'standard_track';
}
$name = trim((string) ($_POST['display_name'] ?? ''));
$pricing = array_fill_keys(array_keys(hs_price_fields($type)), 0);
$settings = hs_effective_formula_settings($type, $pricing);
$customWidth = 150.0;
$customHeight = 150.0;
$preview = null;
$error = null;
$revision = hs_rules_revision();

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!hs_verify_csrf($_POST['csrf_token'] ?? null)) {
        $error = '表單驗證失敗，請重新載入頁面。';
    } elseif (($_POST['action'] ?? '') === 'preview') {
        unset($_SESSION['new_product_preview']);
        $priceCheck = hs_validate_price_fields($type, $_POST);
        $formulaCheck = hs_validate_formula_settings($type, $_POST);
        $rawWidth = $_POST['width_cm'] ?? null;
        $rawHeight = $_POST['height_cm'] ?? null;
        if ($name === '' || strlen($name) > 180 || preg_match('/[\x00-\x1F\x7F]/', $name)) {
            $error = '產品名稱為必填，且不可超過 60 個中文字。';
        } elseif (!$priceCheck['ok']) {
            $error = $priceCheck['message'];
        } elseif (!$formulaCheck['ok']) {
            $error = $formulaCheck['message'];
        } elseif (!is_scalar($rawWidth) || !is_scalar($rawHeight) || !is_numeric($rawWidth) || !is_numeric($rawHeight)
            || (float) $rawWidth <= 0 || (float) $rawHeight <= 0 || (float) $rawWidth > 10000 || (float) $rawHeight > 10000) {
            $error = '試算寬高須介於 0 至 10000 cm。';
        } elseif (!hs_preview_quotes_are_valid($type, $priceCheck['pricing'], $formulaCheck['settings'], (float) $rawWidth, (float) $rawHeight)) {
            $error = '參數會產生無效或過大的報價，請調整後重新預覽。';
        } else {
            $pricing = $priceCheck['pricing'];
            $settings = $formulaCheck['settings'];
            $customWidth = (float) $rawWidth;
            $customHeight = (float) $rawHeight;
            $preview = ['pricing' => $pricing, 'settings' => $settings];
            $_SESSION['new_product_preview'] = [
                'revision' => $revision,
                'name' => $name,
                'type' => $type,
                'pricing' => $pricing,
                'settings' => $settings,
            ];
        }
    } elseif (($_POST['action'] ?? '') === 'create') {
        $pending = $_SESSION['new_product_preview'] ?? null;
        if (!is_array($pending) || ($pending['revision'] ?? '') !== $revision) {
            $error = '規則已更新或尚未完成預覽，請重新試算。';
        } else {
            $outcome = hs_with_lock('pricing-rules', function () use ($pending, $revision) {
                if (hs_rules_revision() !== $revision) {
                    return ['ok' => false, 'message' => '其他人已更新規則，請重新載入並試算。'];
                }
                $rules = hs_read_rules();
                foreach (($rules['products'] ?? []) as $id => $product) {
                    if (is_array($product) && hs_product_display_name((string) $id, $product) === $pending['name']) {
                        return ['ok' => false, 'message' => '產品名稱已存在。'];
                    }
                }
                $backup = hs_backup_rules();
                if ($backup === null) {
                    return ['ok' => false, 'message' => '建立備份失敗。'];
                }
                $id = hs_next_product_id($rules);
                if ($id === null) {
                    return ['ok' => false, 'message' => '分配產品 ID 失敗。'];
                }
                $type = $pending['type'];
                $rules['products'][$id] = [
                    'name' => $pending['name'],
                    'display_name' => $pending['name'],
                    'formula_type' => $type,
                    'requires_track' => hs_formula_requires_track($type),
                    'status' => 'draft',
                    'pricing' => hs_sync_legacy_formula_fields($pending['pricing'], $pending['settings']),
                    'formula_settings' => $pending['settings'],
                ];
                $rules['updated_at'] = hs_now_iso();
                $rules['version'] = hs_next_rules_version();
                if (!hs_save_rules($rules)) {
                    return ['ok' => false, 'message' => '儲存產品失敗。'];
                }
                return ['ok' => true, 'id' => $id, 'backup' => basename($backup)];
            });
            if ($outcome['ok']) {
                unset($_SESSION['new_product_preview']);
                hs_audit_log('product_created', ['product_id' => $outcome['id'], 'backup_file' => $outcome['backup']]);
                hs_set_flash('success', '產品草稿已建立。請在公式頁再次試算並上架。');
                header('Location: /admin/pricing/formula.php?product_id=' . rawurlencode($outcome['id']));
                exit;
            }
            $error = $outcome['message'];
        }
    }
}
?>
<!doctype html>
<html lang="zh-Hant"><head><meta charset="utf-8" /><meta name="viewport" content="width=device-width, initial-scale=1" />
<title>新增試算產品</title><?php hs_admin_page_style(); ?></head>
<body><main>
  <p><a href="/admin/pricing/">← 返回價格規則後台</a></p>
  <section class="panel"><h1>新增試算產品</h1>
    <p>先選現有公式模板，再填價格與專屬參數。產品建立後為草稿，不會立刻出現在前台。</p>
    <form method="get" class="actions">
      <label for="template">公式模板</label>
      <select id="template" name="formula_type" style="width:auto;min-width:220px">
        <?php foreach ($definitions as $key => $definition): ?><option value="<?= hs_admin_h($key) ?>" <?= $key === $type ? 'selected' : '' ?>><?= hs_admin_h($definition['label']) ?></option><?php endforeach; ?>
      </select>
      <button class="secondary" type="submit">選擇模板</button>
    </form>
    <p class="muted"><?= hs_admin_h($definitions[$type]['steps']) ?></p>
  </section>
  <?php if ($error): ?><div class="message error"><?= hs_admin_h($error) ?></div><?php endif; ?>
  <form method="post" id="new-preview-form">
    <input type="hidden" name="csrf_token" value="<?= hs_admin_h(hs_csrf_token()) ?>" />
    <input type="hidden" name="action" value="preview" />
    <input type="hidden" name="formula_type" value="<?= hs_admin_h($type) ?>" />
    <section class="panel"><h2>產品資料與價格</h2>
      <div class="field" style="margin-bottom:16px"><label for="display_name">產品名稱</label><input id="display_name" name="display_name" maxlength="180" required value="<?= hs_admin_h($name) ?>" /></div>
      <div class="grid"><?php hs_render_price_fields($type, $pricing); ?></div>
    </section>
    <section class="panel"><h2>公式參數</h2><div class="grid"><?php hs_render_formula_fields($type, $settings); ?></div></section>
    <section class="panel"><h2>自訂試算尺寸</h2><div class="grid">
      <div class="field"><label for="width_cm">寬度（cm）</label><input id="width_cm" name="width_cm" type="number" min="0.01" max="10000" step="0.01" required value="<?= hs_admin_h($customWidth) ?>" /></div>
      <div class="field"><label for="height_cm">高度（cm）</label><input id="height_cm" name="height_cm" type="number" min="0.01" max="10000" step="0.01" required value="<?= hs_admin_h($customHeight) ?>" /></div>
    </div><div class="actions"><button type="submit">預覽新產品報價</button></div></section>
  </form>
  <?php if ($preview): ?>
    <section class="panel"><h2>試算預覽</h2>
      <?php hs_render_preview_table($type, array_fill_keys(array_keys(hs_price_fields($type)), 0), $settings, $pricing, $settings, $customWidth, $customHeight); ?>
      <p class="muted">左欄以零價格作參照；新產品尚未建立。若修改上方內容，請重新預覽。</p>
      <form method="post" class="actions" id="new-create-form">
        <input type="hidden" name="csrf_token" value="<?= hs_admin_h(hs_csrf_token()) ?>" />
        <button type="submit" name="action" value="create">建立產品草稿</button>
      </form>
    </section>
  <?php endif; ?>
  <script>
    const previewForm = document.getElementById('new-preview-form');
    const createForm = document.getElementById('new-create-form');
    if (previewForm && createForm) {
      const requireNewPreview = () => {
        createForm.querySelectorAll('button').forEach(button => {
          button.disabled = true;
          button.title = '內容已修改，請重新預覽';
        });
      };
      previewForm.addEventListener('input', requireNewPreview);
      previewForm.addEventListener('change', requireNewPreview);
    }
  </script>
</main></body></html>
