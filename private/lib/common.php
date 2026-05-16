<?php
declare(strict_types=1);

date_default_timezone_set('Asia/Taipei');

const HS_SESSION_NAME = 'hs_pricing_admin';
const HS_SESSION_TIMEOUT_SECONDS = 1800;
const HS_LOGIN_MAX_ATTEMPTS = 5;
const HS_LOGIN_LOCK_SECONDS = 900;
const HS_LOGIN_WINDOW_SECONDS = 900;

function hs_private_root(): string
{
    return dirname(__DIR__);
}

function hs_path(string $relativePath): string
{
    $normalized = str_replace(['/', '\\'], DIRECTORY_SEPARATOR, $relativePath);
    return hs_private_root() . DIRECTORY_SEPARATOR . $normalized;
}

function hs_now_iso(): string
{
    return date('c');
}

function hs_client_ip(): string
{
    $ip = $_SERVER['REMOTE_ADDR'] ?? '';
    return is_string($ip) && $ip !== '' ? $ip : 'unknown';
}

function hs_ensure_private_dirs(): void
{
    foreach (['backups', 'logs', 'runtime'] as $dir) {
        $path = hs_path($dir);
        if (!is_dir($path)) {
            mkdir($path, 0755, true);
        }
    }
}

function hs_bootstrap_session(): void
{
    hs_ensure_private_dirs();
    if (session_status() === PHP_SESSION_NONE) {
        $isHttps = !empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off';
        session_name(HS_SESSION_NAME);
        session_set_cookie_params([
            'lifetime' => 0,
            'path' => '/',
            'domain' => '',
            'secure' => $isHttps,
            'httponly' => true,
            'samesite' => 'Lax',
        ]);
        session_start();
    }

    $now = time();
    $lastActivity = $_SESSION['last_activity_at'] ?? null;
    if (is_int($lastActivity) && ($now - $lastActivity) > HS_SESSION_TIMEOUT_SECONDS) {
        hs_destroy_session();
        session_start();
    }
    $_SESSION['last_activity_at'] = $now;
}

function hs_destroy_session(): void
{
    $_SESSION = [];
    if (session_status() === PHP_SESSION_ACTIVE) {
        if (ini_get('session.use_cookies')) {
            $params = session_get_cookie_params();
            setcookie(
                session_name(),
                '',
                time() - 42000,
                $params['path'],
                $params['domain'],
                (bool) $params['secure'],
                (bool) $params['httponly']
            );
        }
        session_destroy();
    }
}

function hs_csrf_token(): string
{
    if (empty($_SESSION['csrf_token']) || !is_string($_SESSION['csrf_token'])) {
        $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
    }
    return $_SESSION['csrf_token'];
}

function hs_verify_csrf(?string $token): bool
{
    $sessionToken = $_SESSION['csrf_token'] ?? null;
    if (!is_string($token) || !is_string($sessionToken)) {
        return false;
    }
    return hash_equals($sessionToken, $token);
}

function hs_set_flash(string $type, string $message): void
{
    $_SESSION['flash'] = ['type' => $type, 'message' => $message];
}

function hs_get_flash(): ?array
{
    $flash = $_SESSION['flash'] ?? null;
    unset($_SESSION['flash']);
    return is_array($flash) ? $flash : null;
}

function hs_response_json(int $status, array $payload): void
{
    http_response_code($status);
    header('Content-Type: application/json; charset=UTF-8');
    echo json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function hs_read_json_file(string $path, array $default): array
{
    if (!is_file($path)) {
        return $default;
    }
    $raw = file_get_contents($path);
    if ($raw === false || trim($raw) === '') {
        return $default;
    }
    $decoded = json_decode($raw, true);
    return is_array($decoded) ? $decoded : $default;
}

function hs_write_json_file(string $path, array $data): bool
{
    $encoded = json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    if (!is_string($encoded)) {
        return false;
    }
    return hs_atomic_write($path, $encoded . PHP_EOL);
}

function hs_atomic_write(string $path, string $contents): bool
{
    $dir = dirname($path);
    if (!is_dir($dir) && !mkdir($dir, 0755, true) && !is_dir($dir)) {
        return false;
    }

    $tmpPath = $path . '.tmp.' . bin2hex(random_bytes(4));
    if (file_put_contents($tmpPath, $contents, LOCK_EX) === false) {
        @unlink($tmpPath);
        return false;
    }

    if (!@rename($tmpPath, $path)) {
        @unlink($tmpPath);
        return false;
    }
    return true;
}

function hs_with_lock(string $lockName, callable $callback)
{
    $lockPath = hs_path('runtime' . DIRECTORY_SEPARATOR . $lockName . '.lock');
    $handle = fopen($lockPath, 'c+');
    if ($handle === false) {
        throw new RuntimeException('Unable to open lock file.');
    }

    try {
        if (!flock($handle, LOCK_EX)) {
            throw new RuntimeException('Unable to acquire lock.');
        }
        return $callback();
    } finally {
        flock($handle, LOCK_UN);
        fclose($handle);
    }
}

function hs_rate_limit_allow(string $bucket, string $identity, int $limit, int $windowSeconds): array
{
    $file = hs_path('runtime' . DIRECTORY_SEPARATOR . $bucket . '.json');
    $key = sha1($identity);
    $now = time();

    return hs_with_lock($bucket . '-rate', function () use ($file, $key, $now, $limit, $windowSeconds) {
        $store = hs_read_json_file($file, []);
        $entry = $store[$key] ?? ['window_start' => $now, 'count' => 0];

        $windowStart = (int) ($entry['window_start'] ?? $now);
        $count = (int) ($entry['count'] ?? 0);

        if (($now - $windowStart) >= $windowSeconds) {
            $windowStart = $now;
            $count = 0;
        }

        if ($count >= $limit) {
            $retryAfter = max(1, $windowSeconds - ($now - $windowStart));
            return ['allowed' => false, 'retry_after' => $retryAfter];
        }

        $count++;
        $store[$key] = ['window_start' => $windowStart, 'count' => $count];
        hs_write_json_file($file, $store);
        return ['allowed' => true, 'retry_after' => 0];
    });
}
