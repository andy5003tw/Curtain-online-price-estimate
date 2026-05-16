<?php
declare(strict_types=1);

function hs_ceil_int(float $value): int
{
    return (int) ceil($value);
}

function hs_ceil_one_decimal(float $value): float
{
    return ceil($value * 10) / 10;
}

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

function hs_calc_price(string $formulaType, float $widthCm, float $heightCm, array $pricing): array
{
    switch ($formulaType) {
        case 'standard_track':
            $ftRaw = hs_ft($widthCm);
            $amplitude = hs_ceil_int(($ftRaw * 2) / 5);
            $yards = hs_ceil_one_decimal(($amplitude * ($heightCm / 30.3 + 1.5)) / 3);
            $trackFt = max(hs_ceil_int($ftRaw), (int) hs_calc_number($pricing, 'min_track_ft', 5));
            $materialCost = ($yards * hs_calc_number($pricing, 'unit_price'))
                + ($trackFt * hs_calc_number($pricing, 'track_price_per_ft'))
                + ($amplitude * hs_calc_number($pricing, 'sewing_fee'));
            $installCost = $trackFt * hs_calc_number($pricing, 'installation_fee');
            break;

        case 'snake_fold':
            $ftRaw = hs_ft($widthCm);
            $amplitude = hs_ceil_int(($ftRaw * 2.5) / 5);
            $yards = hs_ceil_one_decimal(($amplitude * ($heightCm / 30.3 + 1.5)) / 3);
            $trackFt = max(hs_ceil_int($ftRaw), (int) hs_calc_number($pricing, 'min_track_ft', 5));
            $materialCost = ($yards * hs_calc_number($pricing, 'unit_price'))
                + ($trackFt * hs_calc_number($pricing, 'track_price_per_ft'))
                + ($amplitude * hs_calc_number($pricing, 'sewing_fee'));
            $installCost = $trackFt * hs_calc_number($pricing, 'installation_fee');
            break;

        case 'seamless_sheer':
            $ftRaw = hs_ft($widthCm);
            $yards = hs_ceil_one_decimal(($ftRaw * 2.2) / 3);
            $trackFt = max(hs_ceil_int($ftRaw), 5);
            $materialCost = ($yards * hs_calc_number($pricing, 'unit_price'))
                + ($trackFt * hs_calc_number($pricing, 'track_price_per_ft'))
                + ($yards * hs_calc_number($pricing, 'sewing_fee'));
            $installCost = $trackFt * hs_calc_number($pricing, 'installation_fee');
            break;

        case 'roman_shade':
            $ftRaw = hs_ft($widthCm);
            $taiInt = hs_ceil_int(hs_tai($widthCm, $heightCm));
            $amplitude = hs_ceil_int(($ftRaw + 1) / 5);
            $yards = hs_ceil_one_decimal(($amplitude * ($heightCm / 30.3 + 1.5)) / 3);
            $trackFt = max(hs_ceil_int($ftRaw), 3);
            $sewingTotal = max($taiInt, 15) * hs_calc_number($pricing, 'sewing_fee');
            $materialCost = ($yards * hs_calc_number($pricing, 'unit_price'))
                + ($trackFt * hs_calc_number($pricing, 'track_price_per_ft'))
                + $sewingTotal;
            $installFt = max(hs_ceil_int($ftRaw), 5);
            $installCost = $installFt * hs_calc_number($pricing, 'installation_fee');
            break;

        case 'hospital_curtain':
            $ftRaw = hs_ft($widthCm);
            $yards = hs_ceil_one_decimal(($ftRaw * 1.2) / 3);
            $trackFt = max(hs_ceil_int($ftRaw), 5);
            $sewingUnits = hs_ceil_int(($ftRaw * 1.2) / 16);
            $materialCost = ($yards * hs_calc_number($pricing, 'unit_price'))
                + ($trackFt * hs_calc_number($pricing, 'track_price_per_ft'))
                + ($sewingUnits * hs_calc_number($pricing, 'sewing_fee'));
            $installCost = $trackFt * hs_calc_number($pricing, 'installation_fee');
            break;

        case 'roller_blind':
            $taiInt = hs_ceil_int(($widthCm / 30.3) * max($heightCm / 30.3, 4));
            $materialCost = max($taiInt, (int) hs_calc_number($pricing, 'min_per_tai', 0))
                * hs_calc_number($pricing, 'unit_price');
            $installCost = max($taiInt, (int) hs_calc_number($pricing, 'base_installation_per_tai', 20))
                * hs_calc_number($pricing, 'labor_per_tai', 13);
            break;

        case 'vertical_blind':
            $taiInt = hs_ceil_int(($widthCm / 30.3) * max($heightCm / 30.3, 4));
            $materialCost = max($taiInt, (int) hs_calc_number($pricing, 'min_per_tai', 0))
                * hs_calc_number($pricing, 'unit_price');
            $installCost = max($taiInt, (int) hs_calc_number($pricing, 'base_installation_per_tai', 35))
                * hs_calc_number($pricing, 'labor_per_tai', 13);
            break;

        case 'area_based':
            $taiInt = hs_ceil_int(($widthCm / 30.3) * ($heightCm / 30.3));
            $materialCost = max($taiInt, (int) hs_calc_number($pricing, 'min_per_tai', 0))
                * hs_calc_number($pricing, 'unit_price');
            $installCost = max($taiInt, (int) hs_calc_number($pricing, 'base_installation_per_tai', 20))
                * hs_calc_number($pricing, 'labor_per_tai', 13);
            break;

        default:
            throw new InvalidArgumentException('Unsupported formula type.');
    }

    $materialCost = round($materialCost);
    $installCost = round($installCost);
    return [
        'material_cost' => (int) $materialCost,
        'install_cost' => (int) $installCost,
        'total_price' => (int) round($materialCost + $installCost),
    ];
}
