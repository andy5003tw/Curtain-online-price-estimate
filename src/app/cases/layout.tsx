import type { Metadata } from 'next';
import { absoluteUrl } from '@/lib/seo';

export const metadata: Metadata = {
  title: '窗簾施工案例 | 大台北實景作品與安裝紀錄',
  description: '瀏覽宏森窗簾大台北實際施工案例，包含三重、板橋、新莊、台北市等區域的布簾、捲簾、百葉窗、調光簾與蛇形簾作品。',
  alternates: { canonical: absoluteUrl('/cases/') },
  openGraph: {
    title: '窗簾施工案例 | 宏森窗簾',
    description: '大台北窗簾訂製與安裝實景案例，依地區與款式快速查看。',
    url: absoluteUrl('/cases/'),
    images: [{ url: absoluteUrl('/banner_img/banner_01.webp'), width: 1200, height: 630 }],
    locale: 'zh_TW',
    type: 'website',
  },
};

export default function CasesLayout({ children }: { children: React.ReactNode }) {
  return children;
}
