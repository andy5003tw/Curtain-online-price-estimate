import type { Metadata } from 'next';
import type { ReactNode } from 'react';
import { buildOgTwitterMeta } from '@/lib/seo';

const CASES_TITLE = '窗簾施工案例｜客廳窗簾實景、款式比較與估價流程';
const CASES_DESCRIPTION =
  '先看窗簾施工案例與客廳窗簾實景，對照三重、板橋、新莊、台北常見窗型、遮光需求與款式，再接窗簾價格試算與免費丈量。';

export const metadata: Metadata = {
  title: CASES_TITLE,
  description: CASES_DESCRIPTION,
  keywords: [
    '窗簾施工案例',
    '客廳窗簾實景',
    '窗簾實景',
    '窗簾款式比較',
    '窗簾價格試算',
    '三重窗簾案例',
    '台北窗簾案例',
    '客廳窗簾',
    '遮光窗簾案例',
  ],
  ...buildOgTwitterMeta({
    title: CASES_TITLE,
    description: CASES_DESCRIPTION,
    path: '/cases/',
    image: '/Construction%20Cases_img/LINE_ALBUM_20240813三重介壽路-蛇形簾_260414_5.webp',
    imageAlt: '宏森窗簾施工案例與客廳窗簾實景',
  }),
};

export default function CasesLayout({ children }: { children: ReactNode }) {
  return children;
}
