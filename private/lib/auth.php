<?php
declare(strict_types=1);

require_once __DIR__ . '/common.php';
require_once __DIR__ . '/storage.php';
require_once __DIR__ . '/audit.php';

const HS_ALLOWED_ROLES = ['owner', 'admin', 'editor'];

function hs_normalize_username(string $username): string
{
    return strtolower(trim($username));
}

function hs_is_valid_username(string $username): bool
{
    return (bool) preg_match('/^[a-zA-Z0-9_.-]{3,32}$/', $username);
}

function hs_password_policy_error(string $password): ?string
{
    if (strlen($password) < 10) {
        return '密碼長度至少需 10 字元。';
    }
    return null;
}

function hs_active_user_count(array $usersData): int
{
    $count = 0;
    foreach (($usersData['users'] ?? []) as $user) {
        if (($user['status'] ?? '') === 'active') {
            $count++;
        }
    }
    return $count;
}

function hs_active_owner_count(array $usersData): int
{
    $count = 0;
    foreach (($usersData['users'] ?? []) as $user) {
        if (($user['status'] ?? '') === 'active' && ($user['role'] ?? '') === 'owner') {
            $count++;
        }
    }
    return $count;
}

function hs_find_user_index(array $usersData, string $username): ?int
{
    $normalized = hs_normalize_username($username);
    foreach (($usersData['users'] ?? []) as $index => $user) {
        if (hs_normalize_username((string) ($user['username'] ?? '')) === $normalized) {
            return $index;
        }
    }
    return null;
}

function hs_current_user(): ?array
{
    $user = $_SESSION['auth_user'] ?? null;
    return is_array($user) ? $user : null;
}

function hs_is_logged_in(): bool
{
    return hs_current_user() !== null;
}

function hs_login_attempt_file(): string
{
    return hs_path('runtime' . DIRECTORY_SEPARATOR . 'login-attempts.json');
}

function hs_login_lock_status(string $username, string $ip): array
{
    $file = hs_login_attempt_file();
    $key = sha1(hs_normalize_username($username) . '|' . $ip);
    $now = time();

    return hs_with_lock('login-attempts', function () use ($file, $key, $now) {
        $store = hs_read_json_file($file, []);
        $entry = $store[$key] ?? ['count' => 0, 'first_failed_at' => 0, 'locked_until' => 0];

        $count = (int) ($entry['count'] ?? 0);
        $firstFailedAt = (int) ($entry['first_failed_at'] ?? 0);
        $lockedUntil = (int) ($entry['locked_until'] ?? 0);

        if ($firstFailedAt > 0 && ($now - $firstFailedAt) > HS_LOGIN_WINDOW_SECONDS) {
            $count = 0;
            $firstFailedAt = 0;
            $lockedUntil = 0;
            $store[$key] = ['count' => 0, 'first_failed_at' => 0, 'locked_until' => 0];
            hs_write_json_file($file, $store);
        }

        if ($lockedUntil > $now) {
            return ['locked' => true, 'retry_after' => $lockedUntil - $now];
        }

        return ['locked' => false, 'retry_after' => 0];
    });
}

function hs_record_login_failure(string $username, string $ip): void
{
    $file = hs_login_attempt_file();
    $key = sha1(hs_normalize_username($username) . '|' . $ip);
    $now = time();

    hs_with_lock('login-attempts', function () use ($file, $key, $now) {
        $store = hs_read_json_file($file, []);
        $entry = $store[$key] ?? ['count' => 0, 'first_failed_at' => 0, 'locked_until' => 0];

        $count = (int) ($entry['count'] ?? 0);
        $firstFailedAt = (int) ($entry['first_failed_at'] ?? 0);

        if ($firstFailedAt === 0 || ($now - $firstFailedAt) > HS_LOGIN_WINDOW_SECONDS) {
            $count = 0;
            $firstFailedAt = $now;
        }

        $count++;
        $lockedUntil = 0;
        if ($count >= HS_LOGIN_MAX_ATTEMPTS) {
            $lockedUntil = $now + HS_LOGIN_LOCK_SECONDS;
        }

        $store[$key] = [
            'count' => $count,
            'first_failed_at' => $firstFailedAt,
            'locked_until' => $lockedUntil,
        ];
        hs_write_json_file($file, $store);
    });
}

function hs_record_login_success(string $username, string $ip): void
{
    $file = hs_login_attempt_file();
    $key = sha1(hs_normalize_username($username) . '|' . $ip);

    hs_with_lock('login-attempts', function () use ($file, $key) {
        $store = hs_read_json_file($file, []);
        if (isset($store[$key])) {
            unset($store[$key]);
            hs_write_json_file($file, $store);
        }
    });
}

function hs_authenticate(string $username, string $password): array
{
    $normalized = hs_normalize_username($username);
    $ip = hs_client_ip();

    $lock = hs_login_lock_status($normalized, $ip);
    if (($lock['locked'] ?? false) === true) {
        return ['ok' => false, 'message' => '登入失敗次數過多，請稍後再試。'];
    }

    $usersData = hs_read_users();
    $userIndex = hs_find_user_index($usersData, $normalized);
    if ($userIndex === null) {
        hs_record_login_failure($normalized, $ip);
        return ['ok' => false, 'message' => '帳號或密碼錯誤。'];
    }

    $user = $usersData['users'][$userIndex];
    if (($user['status'] ?? 'disabled') !== 'active') {
        hs_record_login_failure($normalized, $ip);
        return ['ok' => false, 'message' => '帳號已停用。'];
    }

    $hash = (string) ($user['password_hash'] ?? '');
    if ($hash === '' || !password_verify($password, $hash)) {
        hs_record_login_failure($normalized, $ip);
        return ['ok' => false, 'message' => '帳號或密碼錯誤。'];
    }

    hs_record_login_success($normalized, $ip);
    return ['ok' => true, 'user' => $user];
}

function hs_sign_in_user(array $user): void
{
    session_regenerate_id(true);
    $_SESSION['auth_user'] = [
        'username' => (string) ($user['username'] ?? ''),
        'role' => (string) ($user['role'] ?? 'editor'),
        'status' => (string) ($user['status'] ?? 'active'),
    ];
    $_SESSION['last_activity_at'] = time();
}

function hs_sign_out_user(): void
{
    hs_destroy_session();
}

function hs_role_is_allowed(string $role): bool
{
    return in_array($role, HS_ALLOWED_ROLES, true);
}

function hs_user_has_role(array $user, array $allowedRoles): bool
{
    $role = (string) ($user['role'] ?? '');
    return in_array($role, $allowedRoles, true);
}

function hs_require_login(): void
{
    if (!hs_is_logged_in()) {
        header('Location: /admin/pricing/login.php');
        exit;
    }
}

function hs_require_roles(array $allowedRoles): void
{
    hs_require_login();
    $user = hs_current_user();
    if ($user === null || !hs_user_has_role($user, $allowedRoles)) {
        http_response_code(403);
        echo '拒絕存取';
        exit;
    }
}

function hs_can_manage_users(): bool
{
    $user = hs_current_user();
    return is_array($user) && hs_user_has_role($user, ['owner']);
}

function hs_can_rollback_rules(): bool
{
    $user = hs_current_user();
    return is_array($user) && hs_user_has_role($user, ['owner']);
}

function hs_can_edit_pricing(): bool
{
    $user = hs_current_user();
    return is_array($user) && hs_user_has_role($user, ['owner', 'admin', 'editor']);
}
