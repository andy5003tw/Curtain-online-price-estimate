<?php
declare(strict_types=1);

require_once dirname(__DIR__, 2) . '/private/lib/common.php';
require_once dirname(__DIR__, 2) . '/private/lib/auth.php';
require_once dirname(__DIR__, 2) . '/private/lib/audit.php';

hs_bootstrap_session();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header('Location: /admin/pricing/login.php');
    exit;
}

if (!hs_verify_csrf($_POST['csrf_token'] ?? null)) {
    hs_set_flash('error', '登出請求無效，請重新操作。');
    header('Location: /admin/pricing/');
    exit;
}

$currentUser = hs_current_user();
if ($currentUser !== null) {
    hs_audit_log('logout', ['username' => $currentUser['username'] ?? null]);
}

hs_sign_out_user();
header('Location: /admin/pricing/login.php');
exit;
