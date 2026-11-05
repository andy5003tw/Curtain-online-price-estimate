<?php
declare(strict_types=1);

function hs_admin_h($value): string
{
    return htmlspecialchars((string) $value, ENT_QUOTES, 'UTF-8');
}

function hs_render_formula_fields(string $type, array $settings, bool $disabled = false): void
{
    $definition = hs_formula_definition($type);
    if ($definition === null) {
        return;
    }
    foreach ($definition['fields'] as $key => [$label, , $kind]) {
        $value = $settings[$key] ?? '';
        echo '<div class="field"><label for="param_' . hs_admin_h($key) . '">' . hs_admin_h($label) . '</label>';
        if ($kind === 'round') {
            echo '<select id="param_' . hs_admin_h($key) . '" name="param_' . hs_admin_h($key) . '"' . ($disabled ? ' disabled' : '') . '>';
            foreach (['ceil' => '無條件進位', 'nearest' => '四捨五入', 'floor' => '無條件捨去'] as $option => $optionLabel) {
                echo '<option value="' . hs_admin_h($option) . '"' . ($value === $option ? ' selected' : '') . '>' . hs_admin_h($optionLabel) . '</option>';
            }
            echo '</select>';
        } elseif ($kind === 'decimals') {
            echo '<select id="param_' . hs_admin_h($key) . '" name="param_' . hs_admin_h($key) . '"' . ($disabled ? ' disabled' : '') . '>';
            foreach ([0, 1, 2] as $option) {
                echo '<option value="' . $option . '"' . ((int) $value === $option ? ' selected' : '') . '>' . $option . ' 位</option>';
            }
            echo '</select>';
        } else {
            $step = $kind === 'integer' ? '1' : '0.01';
            echo '<input id="param_' . hs_admin_h($key) . '" name="param_' . hs_admin_h($key) . '" type="number" min="0" step="' . $step . '" required value="' . hs_admin_h($value) . '"' . ($disabled ? ' disabled' : '') . ' />';
        }
        echo '</div>';
    }
}

function hs_render_price_fields(string $type, array $pricing): void
{
    foreach (hs_price_fields($type) as $key => $label) {
        echo '<div class="field"><label for="price_' . hs_admin_h($key) . '">' . hs_admin_h($label) . '</label>';
        echo '<input id="price_' . hs_admin_h($key) . '" name="price_' . hs_admin_h($key) . '" type="number" min="0" step="0.01" required value="' . hs_admin_h($pricing[$key] ?? 0) . '" /></div>';
    }
}

function hs_preview_quotes_are_valid(string $type, array $pricing, array $settings, float $width, float $height): bool
{
    try {
        foreach ([[150.0, 150.0], [200.0, 240.0], [$width, $height]] as [$w, $h]) {
            hs_calc_price($type, $w, $h, $pricing, $settings);
        }
        return true;
    } catch (Throwable $exception) {
        return false;
    }
}

function hs_render_preview_table(string $type, array $oldPricing, array $oldSettings, array $newPricing, array $newSettings, float $width, float $height): void
{
    $sizes = [[150.0, 150.0], [200.0, 240.0], [$width, $height]];
    echo '<table><thead><tr><th>尺寸（cm）</th><th>目前材料／安裝／合計</th><th>預覽材料／安裝／合計</th><th>差額</th></tr></thead><tbody>';
    foreach ($sizes as [$w, $h]) {
        $old = hs_calc_price($type, $w, $h, $oldPricing, $oldSettings);
        $new = hs_calc_price($type, $w, $h, $newPricing, $newSettings);
        echo '<tr><td>' . hs_admin_h($w . ' × ' . $h) . '</td><td>';
        echo hs_admin_h(number_format($old['material_cost']) . '／' . number_format($old['install_cost']) . '／' . number_format($old['total_price']));
        echo '</td><td>' . hs_admin_h(number_format($new['material_cost']) . '／' . number_format($new['install_cost']) . '／' . number_format($new['total_price']));
        echo '</td><td>' . hs_admin_h(number_format($new['total_price'] - $old['total_price'])) . '</td></tr>';
    }
    echo '</tbody></table>';
}

function hs_admin_page_style(): void
{
    echo '<style>
      body{font-family:Arial,sans-serif;background:#f4f4f4;color:#222;margin:0}
      main{max-width:1040px;margin:24px auto;padding:0 16px 40px}
      .panel{background:#fff;border:1px solid #ddd;border-radius:10px;padding:20px;margin-bottom:16px}
      h1{font-size:25px;margin:0 0 12px}h2{font-size:19px;margin:0 0 10px}
      p{line-height:1.6}.muted{color:#666;font-size:13px}
      .grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(210px,1fr));gap:14px}
      .field label{display:block;font-size:13px;margin-bottom:5px;font-weight:600}
      input,select{box-sizing:border-box;width:100%;padding:9px;border:1px solid #bbb;border-radius:6px;font-size:15px}
      button,.button{display:inline-block;border:0;border-radius:6px;background:#1f7a8c;color:white;padding:10px 15px;cursor:pointer;font-weight:700;text-decoration:none;font-size:14px}
      button.secondary,.button.secondary{background:#5a6c7d}button.danger{background:#ad3745}
      .actions{display:flex;gap:10px;flex-wrap:wrap;align-items:center;margin-top:17px}
      .message{border-radius:6px;padding:12px;margin-bottom:16px}.error{background:#ffe7e7;color:#8b0000}.success{background:#e8f7e8;color:#216b21}
      table{width:100%;border-collapse:collapse;font-size:14px}th,td{border:1px solid #ddd;padding:8px;text-align:left}th{background:#f7f7f7}
      @media(max-width:700px){table{font-size:12px}th,td{padding:5px}}
    </style>';
}
