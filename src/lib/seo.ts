export const SITE_URL = 'https://online.hong-sen.com';
export const CATALOG_URL = 'https://www.hong-sen.com';
export const COMPANY_NAME = '宏森開發有限公司';
export const SITE_NAME = '宏森窗簾線上估價';
export const DEFAULT_OG_IMAGE = '/banner_img/banner_01.webp';
export const DEFAULT_OG_IMAGE_ALT = '宏森窗簾服務實景';

export function absoluteUrl(path = '/'): string {
  if (/^https?:\/\//.test(path)) return path;
  const normalizedPath = path.startsWith('/') ? path : `/${path}`;
  return `${SITE_URL}${normalizedPath}`;
}

export function productPath(product: { canonicalSlug?: string; slug?: string; id: string }): string {
  return `/products/${product.canonicalSlug || product.slug || product.id}/`;
}

export function buildCanonicalUrl(path: string): string {
  return absoluteUrl(path);
}

export function isLegacyProductIdPath(value: string): boolean {
  return /^P\d{3}$/i.test(value);
}

export function buildCalculatorUrl(productId?: string, areaId?: string): string {
  const params = new URLSearchParams();
  if (productId) {
    params.set('product', productId);
  }
  if (areaId) {
    params.set('area', areaId);
  }
  const query = params.toString();
  return query ? `/calculator/?${query}` : '/calculator/';
}

type OgTwitterInput = {
  title: string;
  description: string;
  path: string;
  image?: string;
  imageAlt?: string;
  type?: 'website' | 'article' | 'product';
};

export function buildOgTwitterMeta({
  title,
  description,
  path,
  image = DEFAULT_OG_IMAGE,
  imageAlt = DEFAULT_OG_IMAGE_ALT,
  type = 'website',
}: OgTwitterInput) {
  const canonical = buildCanonicalUrl(path);
  const imageUrl = absoluteUrl(image);

  return {
    alternates: { canonical },
    openGraph: {
      title,
      description,
      url: canonical,
      images: [{ url: imageUrl, width: 1200, height: 630, alt: imageAlt }],
      locale: 'zh_TW',
      type,
    },
    twitter: {
      card: 'summary_large_image' as const,
      title,
      description,
      images: [imageUrl],
    },
  };
}
