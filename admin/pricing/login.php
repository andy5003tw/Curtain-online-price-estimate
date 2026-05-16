<?php
declare(strict_types=1);

require_once dirname(__DIR__, 2) . '/private/lib/common.php';
require_once dirname(__DIR__, 2) . '/private/lib/storage.php';
require_once dirname(__DIR__, 2) . '/private/lib/auth.php';
require_once dirname(__DIR__, 2) . '/private/lib/audit.php';

hs_bootstrap_session();

if (hs_is_logged_in()) {
    header('Location: /admin/pricing/');
    exit;
}

$usersData = hs_read_users();
$hasUsers = hs_active_user_count($usersData) > 0;
$errorMessage = null;
$flash = hs_get_flash();

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!hs_verify_csrf($_POST['csrf_token'] ?? null)) {
        $errorMessage = '表單驗證失敗，請重新送出。';
    } else {
        $action = (string) ($_POST['action'] ?? 'login');

        if ($action === 'bootstrap' && !$hasUsers) {
            $username = hs_normalize_username((string) ($_POST['username'] ?? ''));
            $password = (string) ($_POST['password'] ?? '');
            $confirmPassword = (string) ($_POST['confirm_password'] ?? '');

            if (!hs_is_valid_username($username)) {
                $errorMessage = '帳號需為 3-32 字元（英數與 _. -）。';
            } elseif ($password !== $confirmPassword) {
                $errorMessage = '密碼與確認密碼不一致。';
            } elseif (($policyError = hs_password_policy_error($password)) !== null) {
                $errorMessage = $policyError;
            } else {
                $created = hs_with_lock('users', function () use ($username, $password) {
                    $latest = hs_read_users();
                    if (hs_active_user_count($latest) > 0) {
                        return false;
                    }

                    $latest['users'] = [[
                        'username' => $username,
                        'password_hash' => password_hash($password, PASSWORD_DEFAULT),
                        'role' => 'owner',
                        'status' => 'active',
                        'created_at' => hs_now_iso(),
                        'updated_at' => hs_now_iso(),
                    ]];
                    $latest['updated_at'] = hs_now_iso();
                    return hs_save_users($latest);
                });

                if ($created) {
                    hs_audit_log('bootstrap_owner_created', ['username' => $username]);
                    hs_set_flash('success', '擁有者帳號已建立，請登入。');
                    header('Location: /admin/pricing/login.php');
                    exit;
                }
                $errorMessage = '初始化已完成，請直接登入。';
            }
        } else {
            $username = (string) ($_POST['username'] ?? '');
            $password = (string) ($_POST['password'] ?? '');
            $auth = hs_authenticate($username, $password);

            if (($auth['ok'] ?? false) === true) {
                hs_sign_in_user((array) $auth['user']);
                hs_audit_log('login_success', ['username' => hs_normalize_username($username)]);
                header('Location: /admin/pricing/');
                exit;
            }

            hs_audit_log('login_failed', ['username' => hs_normalize_username($username)]);
            $errorMessage = (string) ($auth['message'] ?? '帳號或密碼錯誤。');
        }
    }
}
?>
<!doctype html>
<html lang="zh-Hant">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>估價後台登入</title>
  <style>
    body { font-family: Arial, sans-serif; background: #f5f5f5; margin: 0; }
    .wrap { max-width: 460px; margin: 40px auto; background: #fff; border: 1px solid #ddd; border-radius: 10px; padding: 24px; }
    h1 { margin: 0 0 16px; font-size: 22px; }
    p { margin: 6px 0; }
    label { display: block; margin-top: 12px; font-weight: 600; }
    input { width: 100%; box-sizing: border-box; padding: 10px; margin-top: 6px; border: 1px solid #ccc; border-radius: 6px; }
    button { margin-top: 16px; width: 100%; background: #1f7a8c; color: #fff; border: 0; border-radius: 6px; padding: 11px; font-weight: 700; cursor: pointer; }
    .error { background: #ffe7e7; color: #8b0000; border: 1px solid #ffc2c2; border-radius: 6px; padding: 10px; margin-bottom: 12px; }
    .success { background: #e8f7e8; color: #1f6f1f; border: 1px solid #bee7be; border-radius: 6px; padding: 10px; margin-bottom: 12px; }
    .hint { color: #666; font-size: 13px; }
  </style>
</head>
<body>
  <main class="wrap">
    <h1><?= $hasUsers ? '後台登入' : '初始化擁有者帳號' ?></h1>
    <p class="hint">同網域入口：<code>/admin/pricing/login.php</code></p>

    <?php if ($flash && ($flash['type'] ?? '') === 'success'): ?>
      <div class="success"><?= htmlspecialchars((string) ($flash['message'] ?? ''), ENT_QUOTES, 'UTF-8') ?></div>
    <?php endif; ?>

    <?php if ($errorMessage !== null): ?>
      <div class="error"><?= htmlspecialchars($errorMessage, ENT_QUOTES, 'UTF-8') ?></div>
    <?php endif; ?>

    <?php if (!$hasUsers): ?>
      <form method="post">
        <input type="hidden" name="csrf_token" value="<?= htmlspecialchars(hs_csrf_token(), ENT_QUOTES, 'UTF-8') ?>" />
        <input type="hidden" name="action" value="bootstrap" />
        <label for="username">擁有者帳號</label>
        <input id="username" name="username" required />
        <label for="password">擁有者密碼</label>
        <input id="password" name="password" type="password" required />
        <label for="confirm_password">確認密碼</label>
        <input id="confirm_password" name="confirm_password" type="password" required />
        <button type="submit">建立擁有者帳號</button>
      </form>
    <?php else: ?>
      <form method="post">
        <input type="hidden" name="csrf_token" value="<?= htmlspecialchars(hs_csrf_token(), ENT_QUOTES, 'UTF-8') ?>" />
        <input type="hidden" name="action" value="login" />
        <label for="username">帳號</label>
        <input id="username" name="username" required />
        <label for="password">密碼</label>
        <input id="password" name="password" type="password" required />
        <button type="submit">登入</button>
      </form>
    <?php endif; ?>
  </main>
</body>
</html>
