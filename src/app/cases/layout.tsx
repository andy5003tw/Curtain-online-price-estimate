import type { Metadata } from 'next';
import { absoluteUrl } from '@/lib/seo';

export const metadata: Metadata = {
  title: '窗簾施工案例｜客廳窗簾實景、遮光搭配與價格試算入口',
  description: '先看三重、板橋、新莊、台北與士林的窗簾施工案例，快速比較客廳窗簾、遮光窗簾、無縫紗簾與捲簾實景，再接到窗簾價格試算。',
  alternates: { canonical: absoluteUrl('/cases/') },
  openGraph: {
    title: '窗簾施工案例｜客廳窗簾實景與價格試算入口',
    description: '先看大台北窗簾施工案例，再比較客廳窗簾、遮光窗簾與無縫紗簾方案，最後帶尺寸做線上估價。',
    url: absoluteUrl('/cases/'),
    images: [{ url: absoluteUrl('/banner_img/banner_01.webp'), width: 1200, height: 630 }],
    locale: 'zh_TW',
    type: 'website',
  },
};

export default function CasesLayout({ children }: { children: React.ReactNode }) {
  return children;
}
