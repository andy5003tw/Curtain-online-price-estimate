export interface PricingParams {
  unit_price: number;
  track_price_per_ft?: number;
  min_track_ft?: number;
  sewing_fee?: number;
  installation_fee?: number;
  min_per_tai?: number;
  base_installation_per_tai?: number;
  labor_per_tai?: number;
}

export interface CalculationResult {
  material_cost: number;
  install_cost: number;
  total_price: number;
}

const helper = {
  ceilInt: (val: number) => Math.ceil(val),
  ceilToFixed1: (val: number) => Math.ceil(val * 10) / 10,
  getFt: (w: number) => w / 30.3,
  getTai: (w: number, h: number) => (w / 30.3) * (h / 30.3)
};

export const CurtainCalculator: Record<string, (w: number, h: number, p: PricingParams) => CalculationResult> = {
  
  // 1. 一般窗簾 (獨立公式：2倍幅數)
  standard_track: (w, h, p) => {
    const ft_raw = helper.getFt(w);
    const amplitude = helper.ceilInt((ft_raw * 2) / 5); 
    const yards = helper.ceilToFixed1((amplitude * (h / 30.3 + 1.5)) / 3); 
    const track_ft = Math.max(helper.ceilInt(ft_raw), p.min_track_ft || 5); 
    const material_cost = (yards * p.unit_price) + (track_ft * (p.track_price_per_ft || 0)) + (amplitude * (p.sewing_fee || 0));
    const install_cost = track_ft * (p.installation_fee || 0);
    return { material_cost: Math.round(material_cost), install_cost: Math.round(install_cost), total_price: Math.round(material_cost + install_cost) };
  },

  // 3. 蛇形窗簾 (獨立公式：2.5倍幅數)
  snake_fold: (w, h, p) => {
    const ft_raw = helper.getFt(w);
    const amplitude = helper.ceilInt((ft_raw * 2.5) / 5); 
    const yards = helper.ceilToFixed1((amplitude * (h / 30.3 + 1.5)) / 3);
    const track_ft = Math.max(helper.ceilInt(ft_raw), p.min_track_ft || 5);
    const material_cost = (yards * p.unit_price) + (track_ft * (p.track_price_per_ft || 0)) + (amplitude * (p.sewing_fee || 0));
    const install_cost = track_ft * (p.installation_fee || 0);
    return { material_cost: Math.round(material_cost), install_cost: Math.round(install_cost), total_price: Math.round(material_cost + install_cost) };
  },

  // 2. 無縫紗簾
  seamless_sheer: (w, h, p) => {
    const ft_raw = helper.getFt(w);
    const yards = helper.ceilToFixed1((ft_raw * 2.2) / 3); 
    const track_ft = Math.max(helper.ceilInt(ft_raw), 5);
    const material_cost = (yards * p.unit_price) + (track_ft * (p.track_price_per_ft || 0)) + (yards * (p.sewing_fee || 0));
    const install_cost = track_ft * (p.installation_fee || 0);
    return { material_cost: Math.round(material_cost), install_cost: Math.round(install_cost), total_price: Math.round(material_cost + install_cost) };
  },

  // 4. 羅馬簾 (最新修正：施工改為軌道尺寸，最小5尺)
  roman_shade: (w, h, p) => {
    const ft_raw = helper.getFt(w);
    const tai_int = helper.ceilInt(helper.getTai(w, h));
    
    const amplitude = helper.ceilInt((ft_raw + 1) / 5);
    const yards = helper.ceilToFixed1((amplitude * (h / 30.3 + 1.5)) / 3);
    const track_ft = Math.max(helper.ceilInt(ft_raw), 3); // 軌道材料最小3尺
    
    // 車工：才數取整，最小 15 才
    const sewing_total = Math.max(tai_int, 15) * (p.sewing_fee || 0);
    const material_cost = (yards * p.unit_price) + (track_ft * (p.track_price_per_ft || 0)) + sewing_total;
    
    // 施工：依軌道尺寸計算，最小 5 尺 (根據最新需求)
    const install_ft = Math.max(helper.ceilInt(ft_raw), 5);
    const install_cost = install_ft * (p.installation_fee || 0);
    
    return { material_cost: Math.round(material_cost), install_cost: Math.round(install_cost), total_price: Math.round(material_cost + install_cost) };
  },

  // 5. 醫院窗簾
  hospital_curtain: (w, h, p) => {
    const ft_raw = helper.getFt(w);
    const yards = helper.ceilToFixed1((ft_raw * 1.2) / 3);
    const track_ft = Math.max(helper.ceilInt(ft_raw), 5);
    const sewing_units = helper.ceilInt((ft_raw * 1.2) / 16); 
    const material_cost = (yards * p.unit_price) + (track_ft * (p.track_price_per_ft || 0)) + (sewing_units * (p.sewing_fee || 0));
    const install_cost = track_ft * (p.installation_fee || 0);
    return { material_cost: Math.round(material_cost), install_cost: Math.round(install_cost), total_price: Math.round(material_cost + install_cost) };
  },

  // 6. 捲簾 (專用名稱，含最小4尺高限制)
  roller_blind: (w, h, p) => {
    const tai_int = helper.ceilInt((w / 30.3) * Math.max(h / 30.3, 4));
    const material_cost = Math.max(tai_int, p.min_per_tai || 0) * p.unit_price;
    const install_cost = Math.max(tai_int, p.base_installation_per_tai || 20) * (p.labor_per_tai || 13); 
    return { material_cost: Math.round(material_cost), install_cost: Math.round(install_cost), total_price: Math.round(material_cost + install_cost) };
  },

  // 13. 直立簾 (專用名稱，含最小4尺高限制)
  vertical_blind: (w, h, p) => {
    const tai_int = helper.ceilInt((w / 30.3) * Math.max(h / 30.3, 4));
    const material_cost = Math.max(tai_int, p.min_per_tai || 0) * p.unit_price;
    const install_cost = Math.max(tai_int, p.base_installation_per_tai || 35) * (p.labor_per_tai || 13); 
    return { material_cost: Math.round(material_cost), install_cost: Math.round(install_cost), total_price: Math.round(material_cost + install_cost) };
  },

  // 其他才數類 (百葉、竹簾、風琴、調光、柔紗)
  area_based: (w, h, p) => {
    const tai_int = helper.ceilInt((w / 30.3) * (h / 30.3));
    const material_cost = Math.max(tai_int, p.min_per_tai || 0) * p.unit_price;
    const install_cost = Math.max(tai_int, p.base_installation_per_tai || 20) * (p.labor_per_tai || 13); 
    return { material_cost: Math.round(material_cost), install_cost: Math.round(install_cost), total_price: Math.round(material_cost + install_cost) };
  }
};
