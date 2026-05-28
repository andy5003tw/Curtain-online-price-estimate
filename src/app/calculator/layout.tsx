import type { Metadata } from 'next';
import React from 'react';
import { absoluteUrl, buildOgTwitterMeta } from '@/lib/seo';

const CALCULATOR_SNIPPET_VARIANTS = {
  A: {
    title: '窗簾價格試算｜1 分鐘窗簾線上估價與安裝費（三重、台北）',
    description:
      '想找窗簾價格試算？輸入寬高即可完成窗簾線上估價，比較捲簾、鋁百葉、風琴簾與實木百葉窗價格試算，再安排丈量。',
  },
  B: {
    title: '窗簾線上估價：窗簾價格試算、三重窗簾比價與安裝費',
    description:
      '快速完成窗簾線上估價，支援三重窗簾在地比價、實木百葉窗價格試算與安裝費比較，適合先抓預算再丈量。',
  },
} as const;

const calculatorSnippetVariant = process.env.SEO_SNIPPET_VARIANT === 'B' ? 'B' : 'A';
const CALCULATOR_TITLE = CALCULATOR_SNIPPET_VARIANTS[calculatorSnippetVariant].title;
const CALCULATOR_DESCRIPTION = CALCULATOR_SNIPPET_VARIANTS[calculatorSnippetVariant].description;

export const metadata: Metadata = {
  title: CALCULATOR_TITLE,
  description: CALCULATOR_DESCRIPTION,
  keywords: ['窗簾價格試算計算機', '窗簾計算機', '窗簾線上估價', '窗簾估價工具', '窗簾價格', '窗簾價格試算', '窗簾安裝費用', '台北窗簾線上估價', '三重窗簾線上估價', '三重窗簾價格試算', '台北捲簾價格', '三重調光簾價格', '台北實木百葉窗價格', '窗簾報價'],
  ...buildOgTwitterMeta({
    title: CALCULATOR_TITLE,
    description: CALCULATOR_DESCRIPTION,
    path: '/calculator/',
    image: '/banner_img/banner_01.webp',
    imageAlt: '宏森窗簾線上估價',
  }),
};

const calculatorSchema = {
  '@context': 'https://schema.org',
  '@type': 'SoftwareApplication',
  name: '宏森窗簾線上估價系統',
  applicationCategory: 'BusinessApplication',
  operatingSystem: 'Windows, macOS, Android, iOS',
  offers: {
    '@type': 'Offer',
    price: '0',
    priceCurrency: 'TWD'
  },
  description: '宏森窗簾計算機可快速完成窗簾價格試算與窗簾線上估價，輸入尺寸即可比較台北、三重常見窗簾品項價格與安裝預算。'
};

const faqSchema = {
  '@context': 'https://schema.org',
  '@type': 'FAQPage',
  mainEntity: [
    {
      '@type': 'Question',
      name: '窗簾計算機與窗簾估價工具的結果準確嗎？',
      acceptedAnswer: {
        '@type': 'Answer',
        text: '系統會依尺寸與品項即時計算材料與基本施工費，適合先抓預算範圍。最終金額仍以現場丈量窗型、布料等級與安裝條件為準。'
      }
    },
    {
      '@type': 'Question',
      name: '估價是否包含施工費？',
      acceptedAnswer: {
        '@type': 'Answer',
        text: '是的，線上估價已包含基本施工費，但不含偏遠區或特殊高風險施工的加價項目。'
      }
    },
    {
      '@type': 'Question',
      name: '窗簾安裝費用怎麼計算？',
      acceptedAnswer: {
        '@type': 'Answer',
        text: '安裝費用會依產品類型、尺寸、才數與施工條件計算。系統會先回傳估算金額，最終仍以現場丈量後確認。'
      }
    },
    {
      '@type': 'Question',
      name: '可以比較鋁百葉、風琴簾等不同品項價格嗎？',
      acceptedAnswer: {
        '@type': 'Answer',
        text: '可以，頁面可快速切換不同窗簾品項，比較各尺寸下的估價差異，再決定後續丈量與施工順序。'
      }
    },
    {
      '@type': 'Question',
      name: '量尺及估價需要收費嗎？',
      acceptedAnswer: {
        '@type': 'Answer',
        text: '宏森開發提供台北市與三重區免費到府量尺服務，先估價再安排丈量，流程透明無隱藏費用。'
      }
    },
    {
      '@type': 'Question',
      name: '三重窗簾價格試算後如何比價最有效率？',
      acceptedAnswer: {
        '@type': 'Answer',
        text: '建議固定同一尺寸比較捲簾、調光簾、實木百葉窗三個品項，再從三重窗簾服務頁預約丈量，能最快確認正式報價。'
      }
    }
  ]
};

const breadcrumbSchema = {
  '@context': 'https://schema.org',
  '@type': 'BreadcrumbList',
  itemListElement: [
    { '@type': 'ListItem', position: 1, name: '首頁', item: absoluteUrl('/') },
    { '@type': 'ListItem', position: 2, name: '線上估價', item: absoluteUrl('/calculator/') }
  ]
};

export default function CalculatorLayout({ children }: { children: React.ReactNode }) {
  return (
    <>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(calculatorSchema) }} />
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(faqSchema) }} />
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(breadcrumbSchema) }} />
      {children}
    </>
  );
}
