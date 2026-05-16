<?php
declare(strict_types=1);

require_once dirname(__DIR__, 2) . '/private/lib/common.php';
require_once dirname(__DIR__, 2) . '/private/lib/storage.php';
require_once dirname(__DIR__, 2) . '/private/lib/auth.php';
require_once dirname(__DIR__, 2) . '/private/lib/audit.php';

hs_bootstrap_session();
hs_require_login();

$currentUser = hs_current_user();
if ($currentUser === null) {
    header('Location: /admin/pricing/login.php');
    exit;
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!hs_verify_csrf($_POST['csrf_token'] ?? null)) {
        hs_set_flash('error', '表單驗證失敗，請重新送出。');
        header('Location: /admin/pricing/');
        exit;
    }

    $action = (string) ($_POST['action'] ?? '');
    if ($action === 'save_product') {
        if (!hs_can_edit_pricing()) {
            hs_set_flash('error', '你沒有修改價格的權限。');
            header('Location: /admin/pricing/');
            exit;
        }

        $productId = strtoupper(trim((string) ($_POST['product_id'] ?? '')));
        $saveResult = hs_with_lock('pricing-rules', function () use ($productId) {
            $rules = hs_read_rules();
            $products = $rules['products'] ?? [];
            if (!is_array($products) || !isset($products[$productId])) {
                return ['ok' => false, 'message' => '找不到產品資料。'];
            }

            $product = $products[$productId];
            $pricing = $product['pricing'] ?? null;
            if (!is_array($pricing)) {
                return ['ok' => false, 'message' => '價格規則格式無效。'];
            }

            $changes = [];
            foreach ($pricing as $key => $oldValue) {
                $inputName = 'price_' . $key;
                if (!array_key_exists($inputName, $_POST)) {
                    continue;
                }

                $raw = trim((string) $_POST[$inputName]);
                if ($raw === '' || !is_numeric($raw)) {
                    return ['ok' => false, 'message' => $key . ' 的數值格式錯誤。'];
                }

                $numeric = (float) $raw;
                if ($numeric < 0 || $numeric > 100000000) {
                    return ['ok' => false, 'message' => $key . ' 的數值超出允許範圍。'];
                }

                $normalized = abs($numeric - round($numeric)) < 0.000001 ? (int) round($numeric) : round($numeric, 2);
                if ((float) $oldValue !== (float) $normalized) {
                    $changes[] = [
                        'field' => $key,
                        'old' => $oldValue,
                        'new' => $normalized,
                    ];
                    $pricing[$key] = $normalized;
                }
            }

            if (count($changes) === 0) {
                return ['ok' => true, 'message' => '未偵測到價格異動。', 'changes' => []];
            }

            $backupFile = hs_backup_rules();
            if ($backupFile === null) {
                return ['ok' => false, 'message' => '儲存前建立備份失敗。'];
            }

            $rules['products'][$productId]['pricing'] = $pricing;
            $rules['updated_at'] = hs_now_iso();
            $rules['version'] = 'manual-' . date('Ymd-His');
            if (!hs_save_rules($rules)) {
                return ['ok' => false, 'message' => '儲存價格規則失敗。'];
            }

            return [
                'ok' => true,
                'message' => '價格更新成功。',
                'changes' => $changes,
                'backup_file' => $backupFile,
            ];
        });

        if (($saveResult['ok'] ?? false) === true) {
            foreach (($saveResult['changes'] ?? []) as $change) {
                hs_audit_log('pricing_field_updated', [
                    'product_id' => $productId,
                    'field' => $change['field'],
                    'old' => $change['old'],
                    'new' => $change['new'],
                ]);
            }
            hs_set_flash('success', (string) ($saveResult['message'] ?? '已儲存。'));
        } else {
            hs_set_flash('error', (string) ($saveResult['message'] ?? '儲存失敗。'));
        }

        header('Location: /admin/pricing/');
        exit;
    }

    if ($action === 'rollback_latest') {
        if (!hs_can_rollback_rules()) {
            hs_set_flash('error', '只有擁有者可回滾規則。');
            header('Location: /admin/pricing/');
            exit;
        }

        $restoredFrom = null;
        $restored = hs_with_lock('pricing-rules', function () use (&$restoredFrom) {
            return hs_restore_latest_rules_backup($restoredFrom);
        });

        if ($restored) {
            hs_audit_log('pricing_rollback', ['backup_file' => $restoredFrom]);
            hs_set_flash('success', '已完成回滾（使用最新備份）。');
        } else {
            hs_set_flash('error', '回滾失敗：找不到可用備份。');
        }

        header('Location: /admin/pricing/');
        exit;
    }
}

$flash = hs_get_flash();
$rules = hs_read_rules();
$products = $rules['products'] ?? [];
if (!is_array($products)) {
    $products = [];
}
ksort($products);
$backups = array_slice(hs_list_rule_backups(), 0, 5);

function hs_field_label(string $field): string
{
    $labels = [
        'unit_price' => '布料單價',
        'track_price_per_ft' => '軌道單價 / 尺',
        'min_track_ft' => '軌道最低尺數',
        'sewing_fee' => '車工費',
        'installation_fee' => '安裝費',
        'min_per_tai' => '每台最低計價',
        'base_installation_per_tai' => '每台基本安裝費',
        'labor_per_tai' => '每台施工費',
    ];
    return $labels[$field] ?? $field;
}

function hs_role_label_for_admin(string $role): string
{
    $labels = [
        'owner' => '擁有者',
        'admin' => '管理員',
        'editor' => '編輯者',
    ];
    return $labels[$role] ?? $role;
}

function hs_product_name_zh_by_id(string $productId): string
{
    $labels = [
        'P001' => '一般窗簾',
        'P002' => '無縫紗簾',
        'P003' => '蛇形窗簾',
        'P004' => '羅馬簾',
        'P005' => '捲簾',
        'P006' => '鋁百葉窗簾',
        'P007' => '木百葉窗簾',
        'P008' => '竹簾',
        'P009' => '風琴簾',
        'P010' => '調光簾',
        'P011' => '柔紗簾',
        'P012' => '醫院窗簾',
        'P013' => '直立簾',
    ];
    return $labels[$productId] ?? '';
}
?>
<!doctype html>
<html lang="zh-Hant">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>價格規則後台</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 0; background: #f4f4f4; color: #1f1f1f; }
    .container { max-width: 1100px; margin: 20px auto; padding: 0 16px 40px; }
    .panel { background: #fff; border: 1px solid #ddd; border-radius: 10px; padding: 16px; margin-bottom: 14px; }
    h1 { margin: 0 0 12px; font-size: 24px; }
    h2 { margin: 0 0 12px; font-size: 20px; }
    .meta { display: flex; gap: 12px; flex-wrap: wrap; font-size: 13px; color: #555; }
    .actions { display: flex; gap: 10px; flex-wrap: wrap; margin-top: 12px; }
    .btn { background: #1f7a8c; color: #fff; border: 0; border-radius: 6px; padding: 10px 14px; cursor: pointer; font-weight: 700; }
    .btn.danger { background: #b23a48; }
    .btn.secondary { background: #5a6c7d; text-decoration: none; display: inline-block; }
    .flash { border-radius: 6px; padding: 10px; margin-bottom: 12px; }
    .flash.success { background: #e8f7e8; border: 1px solid #bee7be; color: #1f6f1f; }
    .flash.error { background: #ffe7e7; border: 1px solid #ffc2c2; color: #8b0000; }
    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 10px 14px; }
    label { display: block; font-size: 12px; color: #555; margin-bottom: 4px; }
    input[type="text"], input[type="number"] { width: 100%; box-sizing: border-box; padding: 8px; border: 1px solid #ccc; border-radius: 6px; }
    .product-head { display: flex; justify-content: space-between; align-items: baseline; gap: 10px; margin-bottom: 10px; }
    .small { color: #666; font-size: 12px; }
    code { background: #f0f0f0; padding: 2px 6px; border-radius: 4px; }
    ul { margin: 0; padding-left: 20px; }
  </style>
</head>
<body>
  <main class="container">
    <div class="panel">
      <h1>價格規則後台</h1>
      <?php if ($flash !== null): ?>
        <div class="flash <?= htmlspecialchars((string) ($flash['type'] ?? 'success'), ENT_QUOTES, 'UTF-8') ?>">
          <?= htmlspecialchars((string) ($flash['message'] ?? ''), ENT_QUOTES, 'UTF-8') ?>
        </div>
      <?php endif; ?>
      <div class="meta">
        <span>登入帳號：<strong><?= htmlspecialchars((string) $currentUser['username'], ENT_QUOTES, 'UTF-8') ?></strong></span>
        <span>權限角色：<strong><?= htmlspecialchars(hs_role_label_for_admin((string) $currentUser['role']), ENT_QUOTES, 'UTF-8') ?></strong></span>
        <span>規則版本：<code><?= htmlspecialchars((string) ($rules['version'] ?? '無'), ENT_QUOTES, 'UTF-8') ?></code></span>
        <span>最後更新：<code><?= htmlspecialchars((string) ($rules['updated_at'] ?? '無'), ENT_QUOTES, 'UTF-8') ?></code></span>
      </div>
      <div class="actions">
        <?php if (hs_can_manage_users()): ?>
          <a class="btn secondary" href="/admin/pricing/users.php">人員管理</a>
        <?php endif; ?>
        <?php if (hs_can_rollback_rules()): ?>
          <form method="post" style="display:inline;">
            <input type="hidden" name="csrf_token" value="<?= htmlspecialchars(hs_csrf_token(), ENT_QUOTES, 'UTF-8') ?>" />
            <input type="hidden" name="action" value="rollback_latest" />
            <button class="btn danger" type="submit">回滾最新備份</button>
          </form>
        <?php endif; ?>
        <form method="post" action="/admin/pricing/logout.php" style="display:inline;">
          <input type="hidden" name="csrf_token" value="<?= htmlspecialchars(hs_csrf_token(), ENT_QUOTES, 'UTF-8') ?>" />
          <button class="btn secondary" type="submit">登出</button>
        </form>
      </div>
    </div>

    <div class="panel">
      <h2>最近備份</h2>
      <?php if (count($backups) === 0): ?>
        <p class="small">目前尚無備份檔案。</p>
      <?php else: ?>
        <ul>
          <?php foreach ($backups as $backupPath): ?>
            <li><code><?= htmlspecialchars(basename($backupPath), ENT_QUOTES, 'UTF-8') ?></code></li>
          <?php endforeach; ?>
        </ul>
      <?php endif; ?>
    </div>

    <?php foreach ($products as $productId => $product): ?>
      <?php
        $pricing = $product['pricing'] ?? [];
        if (!is_array($pricing)) {
            continue;
        }
        $productNameEn = (string) ($product['name'] ?? '');
        $productNameZh = hs_product_name_zh_by_id((string) $productId);
        $productNameDisplay = $productNameEn;
        if ($productNameZh !== '') {
            $productNameDisplay .= '（' . $productNameZh . '）';
        }
      ?>
      <section class="panel">
        <div class="product-head">
          <strong><?= htmlspecialchars((string) $productId, ENT_QUOTES, 'UTF-8') ?> - <?= htmlspecialchars($productNameDisplay, ENT_QUOTES, 'UTF-8') ?></strong>
          <span class="small">公式類型：<code><?= htmlspecialchars((string) ($product['formula_type'] ?? ''), ENT_QUOTES, 'UTF-8') ?></code></span>
        </div>

        <form method="post">
          <input type="hidden" name="csrf_token" value="<?= htmlspecialchars(hs_csrf_token(), ENT_QUOTES, 'UTF-8') ?>" />
          <input type="hidden" name="action" value="save_product" />
          <input type="hidden" name="product_id" value="<?= htmlspecialchars((string) $productId, ENT_QUOTES, 'UTF-8') ?>" />
          <div class="grid">
            <?php foreach ($pricing as $field => $value): ?>
              <div>
                <label for="<?= htmlspecialchars($productId . '-' . $field, ENT_QUOTES, 'UTF-8') ?>"><?= htmlspecialchars(hs_field_label((string) $field), ENT_QUOTES, 'UTF-8') ?></label>
                <input
                  id="<?= htmlspecialchars($productId . '-' . $field, ENT_QUOTES, 'UTF-8') ?>"
                  type="number"
                  step="0.01"
                  name="<?= htmlspecialchars('price_' . (string) $field, ENT_QUOTES, 'UTF-8') ?>"
                  value="<?= htmlspecialchars((string) $value, ENT_QUOTES, 'UTF-8') ?>"
                  <?= hs_can_edit_pricing() ? '' : 'disabled' ?>
                />
              </div>
            <?php endforeach; ?>
          </div>
          <?php if (hs_can_edit_pricing()): ?>
            <div class="actions">
              <button class="btn" type="submit">儲存 <?= htmlspecialchars((string) $productId, ENT_QUOTES, 'UTF-8') ?></button>
            </div>
          <?php else: ?>
            <p class="small">目前權限為唯讀，無法修改價格。</p>
          <?php endif; ?>
        </form>
      </section>
    <?php endforeach; ?>
  </main>
</body>
</html>
