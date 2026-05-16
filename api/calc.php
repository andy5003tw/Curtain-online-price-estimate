<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/private/lib/common.php';
require_once dirname(__DIR__) . '/private/lib/storage.php';
require_once dirname(__DIR__) . '/private/lib/calc_engine.php';
require_once dirname(__DIR__) . '/private/lib/audit.php';

hs_ensure_private_dirs();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    hs_response_json(405, [
        'ok' => false,
        'error_code' => 'METHOD_NOT_ALLOWED',
        'message' => 'Only POST is supported.',
    ]);
}

$rate = hs_rate_limit_allow('calc-api-rate', hs_client_ip(), 240, 60);
if (($rate['allowed'] ?? false) !== true) {
    header('Retry-After: ' . (string) ($rate['retry_after'] ?? 30));
    hs_response_json(429, [
        'ok' => false,
        'error_code' => 'RATE_LIMITED',
        'message' => 'Too many requests. Please try again later.',
    ]);
}

$rawBody = file_get_contents('php://input');
$input = [];
if (is_string($rawBody) && trim($rawBody) !== '') {
    $decoded = json_decode($rawBody, true);
    if (is_array($decoded)) {
        $input = $decoded;
    }
}
if (count($input) === 0) {
    $input = $_POST;
}

$productId = strtoupper(trim((string) ($input['product_id'] ?? '')));
$widthCm = $input['width_cm'] ?? null;
$heightCm = $input['height_cm'] ?? null;

if ($productId === '' || !preg_match('/^P\\d{3}$/', $productId)) {
    hs_response_json(422, [
        'ok' => false,
        'error_code' => 'INVALID_PRODUCT',
        'message' => 'Invalid product id.',
    ]);
}

if (!is_numeric($widthCm) || !is_numeric($heightCm)) {
    hs_response_json(422, [
        'ok' => false,
        'error_code' => 'INVALID_DIMENSION',
        'message' => 'Width and height must be numeric.',
    ]);
}

$width = (float) $widthCm;
$height = (float) $heightCm;
if ($width <= 0 || $height <= 0 || $width > 10000 || $height > 10000) {
    hs_response_json(422, [
        'ok' => false,
        'error_code' => 'OUT_OF_RANGE',
        'message' => 'Width and height are out of allowed range.',
    ]);
}

$rules = hs_read_rules();
$products = $rules['products'] ?? [];
if (!is_array($products) || !isset($products[$productId])) {
    hs_response_json(404, [
        'ok' => false,
        'error_code' => 'PRODUCT_NOT_FOUND',
        'message' => 'Product pricing rule not found.',
    ]);
}

$productRule = $products[$productId];
$formulaType = (string) ($productRule['formula_type'] ?? '');
$pricing = $productRule['pricing'] ?? null;
if ($formulaType === '' || !is_array($pricing)) {
    hs_audit_log('calc_rule_invalid', ['product_id' => $productId]);
    hs_response_json(500, [
        'ok' => false,
        'error_code' => 'RULE_CONFIG_ERROR',
        'message' => 'Pricing rule is unavailable.',
    ]);
}

try {
    $result = hs_calc_price($formulaType, $width, $height, $pricing);
} catch (Throwable $exception) {
    hs_audit_log('calc_failed', [
        'product_id' => $productId,
        'error' => $exception->getMessage(),
    ]);
    hs_response_json(500, [
        'ok' => false,
        'error_code' => 'CALCULATION_FAILED',
        'message' => 'Unable to calculate right now.',
    ]);
}

hs_response_json(200, [
    'ok' => true,
    'data' => $result,
]);
