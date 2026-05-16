<?php
declare(strict_types=1);

require_once dirname(__DIR__, 2) . '/private/lib/common.php';
require_once dirname(__DIR__, 2) . '/private/lib/storage.php';
require_once dirname(__DIR__, 2) . '/private/lib/auth.php';
require_once dirname(__DIR__, 2) . '/private/lib/audit.php';

hs_bootstrap_session();
hs_require_roles(['owner']);

$currentUser = hs_current_user();
if ($currentUser === null) {
    header('Location: /admin/pricing/login.php');
    exit;
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!hs_verify_csrf($_POST['csrf_token'] ?? null)) {
        hs_set_flash('error', '表單驗證失敗，請重新送出。');
        header('Location: /admin/pricing/users.php');
        exit;
    }

    $action = (string) ($_POST['action'] ?? '');
    $result = hs_with_lock('users', function () use ($action, $currentUser) {
        $usersData = hs_read_users();
        $users = $usersData['users'] ?? [];
        if (!is_array($users)) {
            $users = [];
        }

        if ($action === 'add_user') {
            $username = hs_normalize_username((string) ($_POST['username'] ?? ''));
            $password = (string) ($_POST['password'] ?? '');
            $role = (string) ($_POST['role'] ?? 'editor');

            if (!hs_is_valid_username($username)) {
                return ['ok' => false, 'message' => '帳號格式錯誤。'];
            }
            if (!hs_role_is_allowed($role)) {
                return ['ok' => false, 'message' => '角色設定無效。'];
            }
            if (($policyError = hs_password_policy_error($password)) !== null) {
                return ['ok' => false, 'message' => $policyError];
            }
            if (hs_find_user_index($usersData, $username) !== null) {
                return ['ok' => false, 'message' => '帳號已存在。'];
            }

            $users[] = [
                'username' => $username,
                'password_hash' => password_hash($password, PASSWORD_DEFAULT),
                'role' => $role,
                'status' => 'active',
                'created_at' => hs_now_iso(),
                'updated_at' => hs_now_iso(),
            ];

            $usersData['users'] = $users;
            $usersData['updated_at'] = hs_now_iso();
            if (!hs_save_users($usersData)) {
                return ['ok' => false, 'message' => '無法儲存新帳號。'];
            }

            hs_audit_log('user_added', ['username' => $username, 'role' => $role]);
            return ['ok' => true, 'message' => '使用者建立成功。'];
        }

        if ($action === 'reset_password') {
            $username = hs_normalize_username((string) ($_POST['username'] ?? ''));
            $newPassword = (string) ($_POST['new_password'] ?? '');
            if (($policyError = hs_password_policy_error($newPassword)) !== null) {
                return ['ok' => false, 'message' => $policyError];
            }

            $index = hs_find_user_index($usersData, $username);
            if ($index === null) {
                return ['ok' => false, 'message' => '找不到使用者。'];
            }

            $users[$index]['password_hash'] = password_hash($newPassword, PASSWORD_DEFAULT);
            $users[$index]['updated_at'] = hs_now_iso();
            $usersData['users'] = $users;
            $usersData['updated_at'] = hs_now_iso();
            if (!hs_save_users($usersData)) {
                return ['ok' => false, 'message' => '重設密碼失敗。'];
            }

            hs_audit_log('user_password_reset', ['username' => $username]);
            return ['ok' => true, 'message' => '密碼重設成功。'];
        }

        if ($action === 'update_role') {
            $username = hs_normalize_username((string) ($_POST['username'] ?? ''));
            $newRole = (string) ($_POST['role'] ?? 'editor');
            if (!hs_role_is_allowed($newRole)) {
                return ['ok' => false, 'message' => '角色設定無效。'];
            }

            $index = hs_find_user_index($usersData, $username);
            if ($index === null) {
                return ['ok' => false, 'message' => '找不到使用者。'];
            }

            $oldRole = (string) ($users[$index]['role'] ?? 'editor');
            $status = (string) ($users[$index]['status'] ?? 'disabled');
            if ($oldRole === 'owner' && $newRole !== 'owner' && $status === 'active' && hs_active_owner_count($usersData) <= 1) {
                return ['ok' => false, 'message' => '至少需保留一位啟用中的擁有者。'];
            }

            $users[$index]['role'] = $newRole;
            $users[$index]['updated_at'] = hs_now_iso();
            $usersData['users'] = $users;
            $usersData['updated_at'] = hs_now_iso();
            if (!hs_save_users($usersData)) {
                return ['ok' => false, 'message' => '更新角色失敗。'];
            }

            hs_audit_log('user_role_updated', ['username' => $username, 'old_role' => $oldRole, 'new_role' => $newRole]);
            return ['ok' => true, 'message' => '角色更新成功。'];
        }

        if ($action === 'toggle_status') {
            $username = hs_normalize_username((string) ($_POST['username'] ?? ''));
            $newStatus = (string) ($_POST['status'] ?? 'disabled');
            if (!in_array($newStatus, ['active', 'disabled'], true)) {
                return ['ok' => false, 'message' => '帳號狀態無效。'];
            }

            $index = hs_find_user_index($usersData, $username);
            if ($index === null) {
                return ['ok' => false, 'message' => '找不到使用者。'];
            }

            $oldStatus = (string) ($users[$index]['status'] ?? 'disabled');
            $role = (string) ($users[$index]['role'] ?? 'editor');

            if ($newStatus === 'disabled') {
                if (hs_normalize_username((string) $currentUser['username']) === $username) {
                    return ['ok' => false, 'message' => '無法停用目前登入中的自己帳號。'];
                }
                if ($role === 'owner' && $oldStatus === 'active' && hs_active_owner_count($usersData) <= 1) {
                    return ['ok' => false, 'message' => '至少需保留一位啟用中的擁有者。'];
                }
            }

            $users[$index]['status'] = $newStatus;
            $users[$index]['updated_at'] = hs_now_iso();
            $usersData['users'] = $users;
            $usersData['updated_at'] = hs_now_iso();
            if (!hs_save_users($usersData)) {
                return ['ok' => false, 'message' => '更新狀態失敗。'];
            }

            hs_audit_log('user_status_updated', ['username' => $username, 'old_status' => $oldStatus, 'new_status' => $newStatus]);
            return ['ok' => true, 'message' => '狀態更新成功。'];
        }

        return ['ok' => false, 'message' => '不支援的操作。'];
    });

    hs_set_flash(($result['ok'] ?? false) ? 'success' : 'error', (string) ($result['message'] ?? '請求失敗。'));
    header('Location: /admin/pricing/users.php');
    exit;
}

$flash = hs_get_flash();
$usersData = hs_read_users();
$users = $usersData['users'] ?? [];
if (!is_array($users)) {
    $users = [];
}
usort($users, static function (array $a, array $b): int {
    return strcmp((string) ($a['username'] ?? ''), (string) ($b['username'] ?? ''));
});

function hs_role_label_for_users(string $role): string
{
    $labels = [
        'owner' => '擁有者',
        'admin' => '管理員',
        'editor' => '編輯者',
    ];
    return $labels[$role] ?? $role;
}

function hs_status_label_for_users(string $status): string
{
    $labels = [
        'active' => '啟用',
        'disabled' => '停用',
    ];
    return $labels[$status] ?? $status;
}
?>
<!doctype html>
<html lang="zh-Hant">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>使用者管理</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 0; background: #f4f4f4; color: #1f1f1f; }
    .container { max-width: 1100px; margin: 20px auto; padding: 0 16px 40px; }
    .panel { background: #fff; border: 1px solid #ddd; border-radius: 10px; padding: 16px; margin-bottom: 14px; }
    h1 { margin: 0 0 12px; font-size: 24px; }
    h2 { margin: 0 0 12px; font-size: 20px; }
    .flash { border-radius: 6px; padding: 10px; margin-bottom: 12px; }
    .flash.success { background: #e8f7e8; border: 1px solid #bee7be; color: #1f6f1f; }
    .flash.error { background: #ffe7e7; border: 1px solid #ffc2c2; color: #8b0000; }
    table { width: 100%; border-collapse: collapse; font-size: 14px; }
    th, td { border: 1px solid #ddd; padding: 8px; vertical-align: top; }
    th { background: #fafafa; text-align: left; }
    .actions { display: flex; gap: 8px; flex-wrap: wrap; }
    input, select { padding: 7px; border: 1px solid #ccc; border-radius: 6px; }
    .btn { background: #1f7a8c; color: #fff; border: 0; border-radius: 6px; padding: 8px 12px; cursor: pointer; font-weight: 700; }
    .btn.secondary { background: #5a6c7d; text-decoration: none; display: inline-block; }
    .small { font-size: 12px; color: #666; }
    .inline { display: inline-flex; gap: 6px; align-items: center; flex-wrap: wrap; }
  </style>
</head>
<body>
  <main class="container">
    <section class="panel">
      <h1>使用者管理</h1>
      <?php if ($flash !== null): ?>
        <div class="flash <?= htmlspecialchars((string) ($flash['type'] ?? 'success'), ENT_QUOTES, 'UTF-8') ?>">
          <?= htmlspecialchars((string) ($flash['message'] ?? ''), ENT_QUOTES, 'UTF-8') ?>
        </div>
      <?php endif; ?>
      <a class="btn secondary" href="/admin/pricing/">返回價格規則後台</a>
    </section>

    <section class="panel">
      <h2>新增使用者</h2>
      <form method="post" class="inline">
        <input type="hidden" name="csrf_token" value="<?= htmlspecialchars(hs_csrf_token(), ENT_QUOTES, 'UTF-8') ?>" />
        <input type="hidden" name="action" value="add_user" />
        <input name="username" placeholder="帳號" required />
        <input name="password" type="password" placeholder="密碼" required />
        <select name="role">
          <option value="editor">編輯者</option>
          <option value="admin">管理員</option>
          <option value="owner">擁有者</option>
        </select>
        <button class="btn" type="submit">建立使用者</button>
      </form>
      <p class="small">帳號規則：3-32 字元，僅限英數與 _. -。密碼規則：至少 10 字元。</p>
    </section>

    <section class="panel">
      <h2>既有使用者</h2>
      <table>
        <thead>
          <tr>
            <th>帳號</th>
            <th>角色</th>
            <th>狀態</th>
            <th>更新時間</th>
            <th>操作</th>
          </tr>
        </thead>
        <tbody>
          <?php foreach ($users as $user): ?>
            <?php
              $username = (string) ($user['username'] ?? '');
              $role = (string) ($user['role'] ?? 'editor');
              $status = (string) ($user['status'] ?? 'disabled');
            ?>
            <tr>
              <td><?= htmlspecialchars($username, ENT_QUOTES, 'UTF-8') ?></td>
              <td><?= htmlspecialchars(hs_role_label_for_users($role), ENT_QUOTES, 'UTF-8') ?></td>
              <td><?= htmlspecialchars(hs_status_label_for_users($status), ENT_QUOTES, 'UTF-8') ?></td>
              <td><?= htmlspecialchars((string) ($user['updated_at'] ?? ''), ENT_QUOTES, 'UTF-8') ?></td>
              <td>
                <div class="actions">
                  <form method="post" class="inline">
                    <input type="hidden" name="csrf_token" value="<?= htmlspecialchars(hs_csrf_token(), ENT_QUOTES, 'UTF-8') ?>" />
                    <input type="hidden" name="action" value="update_role" />
                    <input type="hidden" name="username" value="<?= htmlspecialchars($username, ENT_QUOTES, 'UTF-8') ?>" />
                    <select name="role">
                      <option value="editor" <?= $role === 'editor' ? 'selected' : '' ?>>編輯者</option>
                      <option value="admin" <?= $role === 'admin' ? 'selected' : '' ?>>管理員</option>
                      <option value="owner" <?= $role === 'owner' ? 'selected' : '' ?>>擁有者</option>
                    </select>
                    <button class="btn" type="submit">更新角色</button>
                  </form>

                  <form method="post" class="inline">
                    <input type="hidden" name="csrf_token" value="<?= htmlspecialchars(hs_csrf_token(), ENT_QUOTES, 'UTF-8') ?>" />
                    <input type="hidden" name="action" value="toggle_status" />
                    <input type="hidden" name="username" value="<?= htmlspecialchars($username, ENT_QUOTES, 'UTF-8') ?>" />
                    <input type="hidden" name="status" value="<?= $status === 'active' ? 'disabled' : 'active' ?>" />
                    <button class="btn" type="submit"><?= $status === 'active' ? '停用' : '啟用' ?></button>
                  </form>

                  <form method="post" class="inline">
                    <input type="hidden" name="csrf_token" value="<?= htmlspecialchars(hs_csrf_token(), ENT_QUOTES, 'UTF-8') ?>" />
                    <input type="hidden" name="action" value="reset_password" />
                    <input type="hidden" name="username" value="<?= htmlspecialchars($username, ENT_QUOTES, 'UTF-8') ?>" />
                    <input name="new_password" type="password" placeholder="新密碼" required />
                    <button class="btn" type="submit">重設密碼</button>
                  </form>
                </div>
              </td>
            </tr>
          <?php endforeach; ?>
        </tbody>
      </table>
    </section>
  </main>
</body>
</html>
