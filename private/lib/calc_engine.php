<?php
declare(strict_types=1);

require_once __DIR__ . '/formula_settings.php';

function hs_ft(float $widthCm): float
{
    return $widthCm / 30.3;
}

function hs_tai(float $widthCm, float $heightCm): float
{
    return ($widthCm / 30.3) * ($heightCm / 30.3);
}

function hs_calc_number(array $pricing, string $key, float $default = 0.0): float
{
    $value = $pricing[$key] ?? $default;
    return is_numeric($value) ? (float) $value : $default;
}

function hs_round_quantity(float $value, string $mode, int $decimals = 0): float
{
    $factor = 10 ** $decimals;
    switch ($mode) {
        case 'ceil':
            return ceil($value * $factor) / $factor;
        case 'floor':
            return floor($value * $factor) / $factor;
        case 'nearest':
            return round($value, $decimals);
        default:
            throw new InvalidArgumentException('Unsupported rounding mode.');
    }
}

function hs_calc_price(string $formulaType, float $widthCm, float $heightCm, array $pricing, array $savedSettings = []): array
{
    $s = hs_effective_formula_settings($formulaType, $pricing, $savedSettings);
    $ftRaw = hs_ft($widthCm);
    $materialCost = 0.0;
    $installCost = 0.0;

    switch ($formulaType) {
        case 'standard_track':
        case 'snake_fold':
            $panels = hs_round_quantity(($ftRaw * $s['fold_multiplier']) / $s['panel_divisor_ft'], $s['round_panels']);
            $yards = hs_round_quantity(($panels * ($heightCm / 30.3 + $s['height_allowance_ft'])) / 3, $s['round_yards'], $s['yards_decimals']);
            $trackFt = max(hs_round_quantity($ftRaw, $s['round_track_ft']), $s['min_track_ft']);
            $materialCost = $yards * hs_calc_number($pricing, 'unit_price')
                + $trackFt * hs_calc_number($pricing, 'track_price_per_ft')
                + $panels * hs_calc_number($pricing, 'sewing_fee');
            $installCost = $trackFt * hs_calc_number($pricing, 'installation_fee');
            break;

        case 'seamless_sheer':
            $yards = hs_round_quantity(($ftRaw * $s['width_multiplier']) / 3, $s['round_yards'], $s['yards_decimals']);
            $trackFt = max(hs_round_quantity($ftRaw, $s['round_track_ft']), $s['min_track_ft']);
            $materialCost = $yards * hs_calc_number($pricing, 'unit_price')
                + $trackFt * hs_calc_number($pricing, 'track_price_per_ft')
                + $yards * hs_calc_number($pricing, 'sewing_fee');
            $installCost = $trackFt * hs_calc_number($pricing, 'installation_fee');
            break;

        case 'roman_shade':
            $tai = hs_round_quantity(hs_tai($widthCm, $heightCm), $s['round_tai']);
            $panels = hs_round_quantity(($ftRaw + $s['width_allowance_ft']) / $s['panel_divisor_ft'], $s['round_panels']);
            $yards = hs_round_quantity(($panels * ($heightCm / 30.3 + $s['height_allowance_ft'])) / 3, $s['round_yards'], $s['yards_decimals']);
            $trackFt = max(hs_round_quantity($ftRaw, $s['round_track_ft']), $s['min_track_ft']);
            $materialCost = $yards * hs_calc_number($pricing, 'unit_price')
                + $trackFt * hs_calc_number($pricing, 'track_price_per_ft')
                + max($tai, $s['min_sewing_tai']) * hs_calc_number($pricing, 'sewing_fee');
            $installFt = max(hs_round_quantity($ftRaw, $s['round_install_ft']), $s['min_install_ft']);
            $installCost = $installFt * hs_calc_number($pricing, 'installation_fee');
            break;

        case 'hospital_curtain':
            $yards = hs_round_quantity(($ftRaw * $s['width_multiplier']) / 3, $s['round_yards'], $s['yards_decimals']);
            $trackFt = max(hs_round_quantity($ftRaw, $s['round_track_ft']), $s['min_track_ft']);
            $sewingUnits = hs_round_quantity(($ftRaw * $s['width_multiplier']) / $s['sewing_divisor_ft'], $s['round_sewing_units']);
            $materialCost = $yards * hs_calc_number($pricing, 'unit_price')
                + $trackFt * hs_calc_number($pricing, 'track_price_per_ft')
                + $sewingUnits * hs_calc_number($pricing, 'sewing_fee');
            $installCost = $trackFt * hs_calc_number($pricing, 'installation_fee');
            break;

        case 'roller_blind':
        case 'vertical_blind':
            $tai = hs_round_quantity($ftRaw * max($heightCm / 30.3, $s['min_height_ft']), $s['round_tai']);
            $materialCost = max($tai, $s['min_per_tai']) * hs_calc_number($pricing, 'unit_price');
            $installCost = max($tai, $s['min_install_tai']) * hs_calc_number($pricing, 'labor_per_tai', 13);
            break;

        case 'area_based':
            $tai = hs_round_quantity(hs_tai($widthCm, $heightCm), $s['round_tai']);
            $materialCost = max($tai, $s['min_per_tai']) * hs_calc_number($pricing, 'unit_price');
            $installCost = max($tai, $s['min_install_tai']) * hs_calc_number($pricing, 'labor_per_tai', 13);
            break;

        default:
            throw new InvalidArgumentException('Unsupported formula type.');
    }

    if (!is_finite($materialCost) || !is_finite($installCost) || $materialCost < 0 || $installCost < 0
        || $materialCost > PHP_INT_MAX / 2 || $installCost > PHP_INT_MAX / 2) {
        throw new OutOfRangeException('Calculated price is out of range.');
    }
    $material = (int) hs_round_quantity($materialCost, $s['round_material']);
    $install = (int) hs_round_quantity($installCost, $s['round_install']);
    return [
        'material_cost' => $material,
        'install_cost' => $install,
        'total_price' => $material + $install,
    ];
}
