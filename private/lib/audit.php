<?php
declare(strict_types=1);

require_once __DIR__ . '/common.php';

function hs_audit_log(string $event, array $context = []): void
{
    $username = null;
    if (!empty($_SESSION['auth_user']) && is_array($_SESSION['auth_user'])) {
        $username = $_SESSION['auth_user']['username'] ?? null;
    }

    $entry = [
        'timestamp' => hs_now_iso(),
        'event' => $event,
        'username' => $username,
        'ip' => hs_client_ip(),
        'context' => $context,
    ];

    $file = hs_path('logs' . DIRECTORY_SEPARATOR . 'audit-' . date('Y-m') . '.log');
    $line = json_encode($entry, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    if (!is_string($line)) {
        return;
    }
    file_put_contents($file, $line . PHP_EOL, FILE_APPEND | LOCK_EX);
}
