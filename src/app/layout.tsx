import type { Metadata } from 'next';
import './globals.css';
import Header from '@/components/Header';
import Footer from '@/components/Footer';
import FloatingLineBtn from '@/components/FloatingLineBtn';
import { absoluteUrl, CATALOG_URL, COMPANY_NAME, SITE_URL } from '@/lib/seo';
import { businessEvidence } from '@/data/businessEvidence';
import { withBasePath } from '@/lib/base-path';

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: {
    default: '宏森開發有限公司 | 專業窗簾訂製・三重・新北市',
    template: '%s | 宏森開發有限公司',
  },
  description: '宏森開發提供窗簾訂做、線上估價、丈量與施工服務，服務三重、新北市與台北主要地區；正式報價依窗型、材料、配件及施工條件確認。',
  keywords: ['窗簾', '窗簾訂製', '窗簾推薦', '捲簾', '蛇形窗簾', '羅馬簾', '百葉窗', '風琴簾', '調光簾', '三重窗簾', '新北市窗簾', '線上估價'],
  openGraph: {
    type: 'website',
    locale: 'zh_TW',
    url: absoluteUrl('/'),
    siteName: COMPANY_NAME,
    title: '宏森開發有限公司 | 專業窗簾訂製・三重・新北市',
    description: '窗簾訂製、線上估價、丈量與施工服務；正式報價依現場條件確認。',
    images: [{ url: '/og-image.webp', width: 1200, height: 630, alt: '宏森窗簾' }],
  },
};

const localBusinessSchema = {
  '@context': 'https://schema.org',
  '@type': 'LocalBusiness',
  '@id': businessEvidence.companyEntity.id,
  name: COMPANY_NAME,
  alternateName: '宏森窗簾',
  image: absoluteUrl('/banner_img/banner_01.webp'),
  logo: absoluteUrl('/logo.webp'),
  description: '提供大台北主要服務區的窗簾訂製、線上估價、丈量與施工服務；材料規格與正式報價依個別案件確認。',
  url: absoluteUrl('/'),
  telephone: businessEvidence.companyEntity.telephone,
  email: 'andy5003@hong-sen.com',
  address: {
    '@type': 'PostalAddress',
    streetAddress: '仁愛街125巷89號1樓',
    addressLocality: '三重區',
    addressRegion: '新北市',
    postalCode: '241',
    addressCountry: 'TW',
  },
  geo: {
    '@type': 'GeoCoordinates',
    latitude: 25.0652,
    longitude: 121.4862,
  },
  openingHoursSpecification: businessEvidence.businessHours.openingHoursSpecification,
  areaServed: [
    { '@type': 'City', name: '台北市' },
    { '@type': 'City', name: '新北市' },
    { '@type': 'AdministrativeArea', name: '三重區' },
    { '@type': 'AdministrativeArea', name: '蘆洲區' },
    { '@type': 'AdministrativeArea', name: '板橋區' },
    { '@type': 'AdministrativeArea', name: '新莊區' },
  ],
  priceRange: 'NT$',
  hasMap: 'https://maps.google.com/?q=宏森開發有限公司+新北市三重區',
  sameAs: [
    CATALOG_URL,
    'https://line.me/ti/p/fDWxUXkiZb',
  ],
  knowsAbout: [
    '窗簾訂製',
    '到府丈量流程',
    '蛇形簾',
    '調光簾',
    '百葉窗',
    '防焰窗簾',
    '大台北窗簾施工'
  ],
  makesOffer: [
    {
      '@type': 'Offer',
      itemOffered: {
        '@type': 'Service',
        name: '專業窗簾訂製與施工'
      }
    }
  ]
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="zh-TW">
      <head>
        <link rel="preload" href={withBasePath('/banner_img/banner_01.webp')} as="image" />
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(localBusinessSchema) }}
        />
      </head>
      <body>
        <Header />
        <main>{children}</main>
        <Footer />
        
        {/* Global Floating LINE Button */}
        <FloatingLineBtn />

        <style dangerouslySetInnerHTML={{__html: `
          .floating-line-wrapper {
            position: fixed;
            bottom: 2rem;
            right: 2rem;
            z-index: 100;
          }
          .floating-line-menu {
            position: absolute;
            bottom: 100%;
            right: 0;
            margin-bottom: 1rem;
            background: white;
            border-radius: 1rem;
            box-shadow: 0 4px 20px rgba(0,0,0,0.15);
            padding: 1.5rem;
            display: flex;
            gap: 1.25rem;
            width: max-content;
            opacity: 0;
            visibility: hidden;
            transform: translateY(10px);
            transition: all 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275);
            pointer-events: none;
            cursor: default;
          }
          .floating-line-menu.open {
            opacity: 1;
            visibility: visible;
            transform: translateY(0);
            pointer-events: auto;
          }
          
          .qr-box {
            display: flex;
            flex-direction: column;
            align-items: center;
            gap: 0.5rem;
            width: 120px;
          }
          .qr-title {
            font-size: 0.85rem;
            font-weight: 700;
            color: var(--stone-800);
          }
          .qr-box img {
            width: 120px;
            height: 120px;
            border: 1px solid var(--stone-200);
            border-radius: 0.5rem;
            padding: 0.25rem;
            background: white;
          }
          .qr-box a {
            display: block;
            width: 100%;
            text-align: center;
            font-size: 0.8rem;
            font-weight: 600;
            color: white;
            background: #06C755;
            padding: 0.35rem 0;
            border-radius: 0.25rem;
            text-decoration: none;
            transition: background 0.2s;
          }
          .qr-box a:hover {
            background: #05b04b;
          }
          .qr-divider {
            width: 1px;
            background: var(--stone-100);
          }

          .floating-line-btn {
            background-color: #06C755;
            color: white;
            height: 56px;
            border-radius: 28px;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 0.5rem;
            padding: 0 1.25rem;
            font-weight: 700;
            box-shadow: 0 4px 16px rgba(6, 199, 85, 0.4);
            cursor: pointer;
            transition: all 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275);
            user-select: none;
          }
          .floating-line-btn:hover {
            transform: translateY(-5px) scale(1.05);
            box-shadow: 0 8px 24px rgba(6, 199, 85, 0.5);
          }
          .floating-line-btn:active {
            transform: translateY(-2px) scale(1.02);
            box-shadow: 0 4px 12px rgba(6, 199, 85, 0.4);
          }
          @media (max-width: 768px) {
            .floating-line-menu {
              display: none !important; /* Hide QR menu on mobile completely */
            }
            .floating-line-wrapper {
              display: none; /* 手機板完全隱藏 LINE 諮詢浮動按鈕 */
            }
          }
        `}} />
      </body>
    </html>
  );
}
