<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/private/lib/storage.php';
require_once dirname(__DIR__) . '/private/lib/formula_settings.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    hs_response_json(405, ['ok' => false, 'error_code' => 'METHOD_NOT_ALLOWED', 'message' => 'Only GET is supported.']);
}

header('Cache-Control: no-store, max-age=0');
$rules = hs_read_rules();
$products = $rules['products'] ?? [];
$catalog = [];
if (is_array($products)) {
    ksort($products);
    foreach ($products as $id => $product) {
        if (!is_array($product) || hs_product_status($product) !== 'active') {
            continue;
        }
        $type = (string) ($product['formula_type'] ?? '');
        if (hs_formula_definition($type) === null) {
            continue;
        }
        $catalog[] = [
            'id' => (string) $id,
            'name' => hs_product_display_name((string) $id, $product),
            'requires_track' => hs_formula_requires_track($type),
        ];
    }
}
hs_response_json(200, ['ok' => true, 'data' => $catalog]);
