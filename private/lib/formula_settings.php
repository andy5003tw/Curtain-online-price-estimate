<?php
declare(strict_types=1);

require_once __DIR__ . '/common.php';

/** Each field is [Chinese label, default, kind]. Unit conversions stay in the engine. */
function hs_formula_definitions(): array
{
    $moneyRounding = [
        'round_material' => ['材料費取整（元）', 'nearest', 'round'],
        'round_install' => ['安裝費取整（元）', 'nearest', 'round'],
    ];
    $trackRounding = [
        'round_track_ft' => ['軌道尺數取整', 'ceil', 'round'],
    ];
    $yardRounding = [
        'round_yards' => ['布料碼數取整', 'ceil', 'round'],
        'yards_decimals' => ['布料碼數小數位', 1, 'decimals'],
    ];
    $areaRounding = ['round_tai' => ['才數取整', 'ceil', 'round']];

    return [
        'standard_track' => [
            'label' => '一般軌道窗簾',
            'steps' => '寬度換尺 → 摺數與布料碼數 → 布料＋軌道＋車工 → 軌道安裝費',
            'fields' => [
                'fold_multiplier' => ['摺布倍率', 2, 'positive'],
                'panel_divisor_ft' => ['每摺起算尺數', 5, 'positive'],
                'height_allowance_ft' => ['布料高度加放（尺）', 1.5, 'factor'],
                'min_track_ft' => ['軌道最低計價（尺）', 5, 'integer'],
                'round_panels' => ['摺數取整', 'ceil', 'round'],
            ] + $yardRounding + $trackRounding + $moneyRounding,
        ],
        'snake_fold' => [
            'label' => '蛇形窗簾',
            'steps' => '寬度換尺 → 蛇形摺數與布料碼數 → 布料＋軌道＋車工 → 軌道安裝費',
            'fields' => [
                'fold_multiplier' => ['摺布倍率', 2.5, 'positive'],
                'panel_divisor_ft' => ['每摺起算尺數', 5, 'positive'],
                'height_allowance_ft' => ['布料高度加放（尺）', 1.5, 'factor'],
                'min_track_ft' => ['軌道最低計價（尺）', 5, 'integer'],
                'round_panels' => ['摺數取整', 'ceil', 'round'],
            ] + $yardRounding + $trackRounding + $moneyRounding,
        ],
        'seamless_sheer' => [
            'label' => '無縫紗簾',
            'steps' => '寬度換尺 → 布料碼數 → 布料＋軌道＋碼數車工 → 軌道安裝費',
            'fields' => [
                'width_multiplier' => ['用布倍率', 2.2, 'positive'],
                'min_track_ft' => ['軌道最低計價（尺）', 5, 'integer'],
            ] + $yardRounding + $trackRounding + $moneyRounding,
        ],
        'roman_shade' => [
            'label' => '羅馬簾',
            'steps' => '寬度換尺 → 摺數與布料碼數 → 布料＋軌道＋最低才數車工 → 安裝費',
            'fields' => [
                'width_allowance_ft' => ['寬度加放（尺）', 1, 'factor'],
                'panel_divisor_ft' => ['每摺起算尺數', 5, 'positive'],
                'height_allowance_ft' => ['布料高度加放（尺）', 1.5, 'factor'],
                'min_track_ft' => ['軌道最低計價（尺）', 3, 'integer'],
                'min_sewing_tai' => ['車工最低計價（才）', 15, 'integer'],
                'min_install_ft' => ['安裝最低計價（尺）', 5, 'integer'],
                'round_panels' => ['摺數取整', 'ceil', 'round'],
                'round_tai' => ['車工才數取整', 'ceil', 'round'],
                'round_install_ft' => ['安裝尺數取整', 'ceil', 'round'],
            ] + $yardRounding + $trackRounding + $moneyRounding,
        ],
        'hospital_curtain' => [
            'label' => '醫院隔簾',
            'steps' => '寬度換尺 → 布料碼數與車工單位 → 布料＋軌道＋車工 → 軌道安裝費',
            'fields' => [
                'width_multiplier' => ['用布／車工倍率', 1.2, 'positive'],
                'sewing_divisor_ft' => ['每車工單位尺數', 16, 'positive'],
                'min_track_ft' => ['軌道最低計價（尺）', 5, 'integer'],
                'round_sewing_units' => ['車工單位取整', 'ceil', 'round'],
            ] + $yardRounding + $trackRounding + $moneyRounding,
        ],
        'roller_blind' => [
            'label' => '捲簾',
            'steps' => '寬 × 起算高度換才 → 最低材料才數 × 單價 → 最低安裝才數 × 施工費',
            'fields' => [
                'min_height_ft' => ['高度最低起算（尺）', 4, 'factor'],
                'min_per_tai' => ['材料最低計價（才）', 0, 'integer'],
                'min_install_tai' => ['安裝最低計價（才）', 20, 'integer'],
            ] + $areaRounding + $moneyRounding,
        ],
        'area_based' => [
            'label' => '面積計價',
            'steps' => '寬 × 高換才 → 最低材料才數 × 單價 → 最低安裝才數 × 施工費',
            'fields' => [
                'min_per_tai' => ['材料最低計價（才）', 0, 'integer'],
                'min_install_tai' => ['安裝最低計價（才）', 20, 'integer'],
            ] + $areaRounding + $moneyRounding,
        ],
        'vertical_blind' => [
            'label' => '直立簾',
            'steps' => '寬 × 起算高度換才 → 最低材料才數 × 單價 → 最低安裝才數 × 施工費',
            'fields' => [
                'min_height_ft' => ['高度最低起算（尺）', 4, 'factor'],
                'min_per_tai' => ['材料最低計價（才）', 0, 'integer'],
                'min_install_tai' => ['安裝最低計價（才）', 35, 'integer'],
            ] + $areaRounding + $moneyRounding,
        ],
    ];
}

function hs_formula_definition(string $type): ?array
{
    return hs_formula_definitions()[$type] ?? null;
}

function hs_price_fields(string $type): array
{
    if (in_array($type, ['standard_track', 'snake_fold', 'seamless_sheer', 'roman_shade', 'hospital_curtain'], true)) {
        return [
            'unit_price' => '布料單價',
            'track_price_per_ft' => '軌道單價／尺',
            'sewing_fee' => '車工費',
            'installation_fee' => '安裝費／尺',
        ];
    }
    if (in_array($type, ['roller_blind', 'area_based', 'vertical_blind'], true)) {
        return ['unit_price' => '材料單價／才', 'labor_per_tai' => '施工費／才'];
    }
    return [];
}

function hs_formula_requires_track(string $type): bool
{
    return in_array($type, ['standard_track', 'snake_fold', 'seamless_sheer', 'roman_shade', 'hospital_curtain'], true);
}

function hs_effective_formula_settings(string $type, array $pricing, array $saved = []): array
{
    $definition = hs_formula_definition($type);
    if ($definition === null) {
        throw new InvalidArgumentException('Unsupported formula type.');
    }
    $result = [];
    foreach ($definition['fields'] as $key => $field) {
        $value = $field[1];
        // These fields affected the old engine. P002/P012 min_track_ft did not.
        if ($key === 'min_track_ft' && !in_array($type, ['seamless_sheer', 'hospital_curtain'], true)) {
            $value = (int) ($pricing['min_track_ft'] ?? $value);
        } elseif ($key === 'min_per_tai') {
            $value = (int) ($pricing['min_per_tai'] ?? $value);
        } elseif ($key === 'min_install_tai') {
            $value = (int) ($pricing['base_installation_per_tai'] ?? $value);
        }
        $result[$key] = $saved[$key] ?? $value;
    }
    return $result;
}

function hs_validate_formula_settings(string $type, array $input): array
{
    $definition = hs_formula_definition($type);
    if ($definition === null) {
        return ['ok' => false, 'message' => '不支援的公式類型。'];
    }
    $settings = [];
    foreach ($definition['fields'] as $key => [$label, , $kind]) {
        $raw = $input['param_' . $key] ?? null;
        if (!is_scalar($raw)) {
            return ['ok' => false, 'message' => $label . ' 為必填。'];
        }
        $raw = trim((string) $raw);
        if ($kind === 'round') {
            if (!in_array($raw, ['ceil', 'nearest', 'floor'], true)) {
                return ['ok' => false, 'message' => $label . ' 選項無效。'];
            }
            $settings[$key] = $raw;
            continue;
        }
        if ($kind === 'decimals') {
            if (!in_array($raw, ['0', '1', '2'], true)) {
                return ['ok' => false, 'message' => $label . ' 只能是 0、1 或 2。'];
            }
            $settings[$key] = (int) $raw;
            continue;
        }
        if ($raw === '' || !is_numeric($raw) || !is_finite((float) $raw)) {
            return ['ok' => false, 'message' => $label . ' 必須是有效數字。'];
        }
        $number = (float) $raw;
        $max = $kind === 'integer' ? 10000 : 1000;
        if ($number < 0 || $number > $max || ($kind === 'positive' && $number <= 0)) {
            return ['ok' => false, 'message' => $label . ' 超出允許範圍。'];
        }
        if ($kind === 'integer' && floor($number) !== $number) {
            return ['ok' => false, 'message' => $label . ' 必須是整數。'];
        }
        $settings[$key] = $kind === 'integer' ? (int) $number : round($number, 2);
    }
    return ['ok' => true, 'settings' => $settings];
}

function hs_validate_price_fields(string $type, array $input): array
{
    $pricing = [];
    foreach (hs_price_fields($type) as $key => $label) {
        $raw = $input['price_' . $key] ?? null;
        if (!is_scalar($raw) || trim((string) $raw) === '' || !is_numeric($raw)) {
            return ['ok' => false, 'message' => $label . ' 必須是有效數字。'];
        }
        $number = (float) $raw;
        if (!is_finite($number) || $number < 0 || $number > 100000000) {
            return ['ok' => false, 'message' => $label . ' 超出允許範圍。'];
        }
        $pricing[$key] = round($number, 2);
    }
    return ['ok' => true, 'pricing' => $pricing];
}

function hs_sync_legacy_formula_fields(array $pricing, array $settings): array
{
    foreach (['min_track_ft' => 'min_track_ft', 'min_per_tai' => 'min_per_tai', 'min_install_tai' => 'base_installation_per_tai'] as $setting => $legacy) {
        if (isset($settings[$setting])) {
            $pricing[$legacy] = $settings[$setting];
        }
    }
    return $pricing;
}

function hs_product_status(array $product): string
{
    $status = $product['status'] ?? 'active';
    return in_array($status, ['draft', 'active', 'inactive'], true) ? $status : 'inactive';
}

function hs_product_display_name(string $id, array $product): string
{
    if (isset($product['display_name']) && is_string($product['display_name'])) {
        return $product['display_name'];
    }
    $legacy = [
        'P001' => '一般窗簾', 'P002' => '無縫紗簾', 'P003' => '蛇形窗簾',
        'P004' => '羅馬簾', 'P005' => '捲簾', 'P006' => '鋁百葉窗簾',
        'P007' => '木百葉窗簾', 'P008' => '竹簾', 'P009' => '風琴簾',
        'P010' => '調光簾', 'P011' => '柔紗簾', 'P012' => '醫院窗簾',
        'P013' => '直立簾',
    ];
    return $legacy[$id] ?? (string) ($product['name'] ?? $id);
}

function hs_rules_revision(): string
{
    $hash = is_file(hs_path('pricing-rules.php')) ? hash_file('sha256', hs_path('pricing-rules.php')) : false;
    return is_string($hash) ? $hash : '';
}

function hs_next_rules_version(): string
{
    return 'manual-' . date('Ymd-His') . '-' . bin2hex(random_bytes(3));
}

function hs_next_product_id(array $rules): ?string
{
    $sequencePath = hs_path('runtime/product-sequence.json');
    $sequence = hs_read_json_file($sequencePath, []);
    $highest = max(13, (int) ($sequence['last_number'] ?? 0));
    foreach (array_keys($rules['products'] ?? []) as $id) {
        if (preg_match('/^P(\d+)$/', (string) $id, $matches)) {
            $highest = max($highest, (int) $matches[1]);
        }
    }
    $next = $highest + 1;
    if (!hs_write_json_file($sequencePath, ['last_number' => $next])) {
        return null;
    }
    return 'P' . str_pad((string) $next, 3, '0', STR_PAD_LEFT);
}
