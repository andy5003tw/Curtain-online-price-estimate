<?php
declare(strict_types=1);

require_once __DIR__ . '/common.php';

function hs_rules_file_path(): string
{
    return hs_path('pricing-rules.php');
}

function hs_users_file_path(): string
{
    return hs_path('users.php');
}

function hs_read_php_array_file(string $path, array $default): array
{
    if (!is_file($path)) {
        return $default;
    }

    $data = require $path;
    return is_array($data) ? $data : $default;
}

function hs_export_php_array(array $data): string
{
    return "<?php\n" .
        "declare(strict_types=1);\n\n" .
        'return ' . var_export($data, true) . ";\n";
}

function hs_read_rules(): array
{
    return hs_read_php_array_file(hs_rules_file_path(), ['version' => null, 'updated_at' => null, 'products' => []]);
}

function hs_save_rules(array $rules): bool
{
    return hs_atomic_write(hs_rules_file_path(), hs_export_php_array($rules));
}

function hs_read_users(): array
{
    return hs_read_php_array_file(hs_users_file_path(), ['updated_at' => null, 'users' => []]);
}

function hs_save_users(array $usersData): bool
{
    return hs_atomic_write(hs_users_file_path(), hs_export_php_array($usersData));
}

function hs_backup_rules(): ?string
{
    $source = hs_rules_file_path();
    if (!is_file($source)) {
        return null;
    }

    $backupName = 'pricing-rules-' . date('Ymd-His') . '-' . bin2hex(random_bytes(3)) . '.php';
    $destination = hs_path('backups' . DIRECTORY_SEPARATOR . $backupName);
    if (!copy($source, $destination)) {
        return null;
    }
    return $destination;
}

function hs_list_rule_backups(): array
{
    $pattern = hs_path('backups' . DIRECTORY_SEPARATOR . 'pricing-rules-*.php');
    $files = glob($pattern);
    if (!is_array($files)) {
        return [];
    }
    rsort($files);
    return $files;
}

function hs_restore_latest_rules_backup(?string &$restoredFrom = null): bool
{
    $backups = hs_list_rule_backups();
    if (count($backups) === 0) {
        return false;
    }
    $latest = $backups[0];
    $restoredFrom = $latest;
    return copy($latest, hs_rules_file_path());
}
