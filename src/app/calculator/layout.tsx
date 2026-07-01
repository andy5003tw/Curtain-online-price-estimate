import type { Metadata } from 'next';
import React from 'react';
import { absoluteUrl, buildOgTwitterMeta } from '@/lib/seo';

const CALCULATOR_SNIPPET_VARIANTS = {
  A: {
    title: '窗簾價格試算｜窗簾線上估價、1分鐘比較基本安裝費',
    description:
      '1 分鐘完成窗簾價格試算與窗簾線上估價，含基本安裝費，用同尺寸比較百葉窗、實木百葉、捲簾、紗簾與調光簾。',
  },
  B: {
    title: '窗簾線上估價｜窗簾價格試算、同尺寸比較安裝費',
    description:
      '快速完成窗簾線上估價與窗簾價格試算，支援百葉窗、實木百葉窗、捲簾、紗簾與調光簾比價，先抓合理預算再丈量。',
  },
} as const;

const calculatorSnippetVariant = process.env.SEO_SNIPPET_VARIANT === 'B' ? 'B' : 'A';
const CALCULATOR_TITLE = CALCULATOR_SNIPPET_VARIANTS[calculatorSnippetVariant].title;
const CALCULATOR_DESCRIPTION = CALCULATOR_SNIPPET_VARIANTS[calculatorSnippetVariant].description;

export const metadata: Metadata = {
  title: CALCULATOR_TITLE,
  description: CALCULATOR_DESCRIPTION,
  keywords: ['窗簾價格試算計算機', '窗簾計算機', '窗簾線上估價', '窗簾估價工具', '百葉窗價格試算', '實木百葉窗價格試算', '捲簾價格試算', '調光簾價格試算', '窗簾價格', '窗簾安裝費用', '台北窗簾線上估價', '三重窗簾線上估價', '窗簾報價'],
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
  description: '宏森窗簾計算機可快速完成窗簾價格試算與窗簾線上估價，輸入尺寸即可比較百葉窗、實木百葉、捲簾、調光簾與安裝預算。'
};

const faqSchema = {
  '@context': 'https://schema.org',
  '@type': 'FAQPage',
  mainEntity: [
    {
      '@type': 'Question',
      name: '窗簾價格試算和窗簾線上估價差在哪裡？',
      acceptedAnswer: {
        '@type': 'Answer',
        text: '兩者在本頁是同一個流程：先輸入寬高與品項做窗簾價格試算，系統即時完成窗簾線上估價，並把材料與基本安裝費放進預算區間。'
      }
    },
    {
      '@type': 'Question',
      name: '窗簾價格試算和正式報價會差很多嗎？',
      acceptedAnswer: {
        '@type': 'Answer',
        text: '通常差異不大，但窗型、配件與施工條件會影響最終金額；建議先做窗簾價格試算，再以現場丈量確認正式報價。'
      }
    },
    {
      '@type': 'Question',
      name: '窗簾價格試算怎麼判斷合理？',
      acceptedAnswer: {
        '@type': 'Answer',
        text: '建議固定同一組尺寸比較 2 到 3 種品項，並一起看材料、基本安裝費、窗型與丈量條件。線上估價先抓合理區間，正式報價再由現場確認。'
      }
    },
    {
      '@type': 'Question',
      name: '窗簾線上估價適合先比較哪些品項？',
      acceptedAnswer: {
        '@type': 'Answer',
        text: '若你是第一次比價，建議先固定同一尺寸比較捲簾、鋁百葉、實木百葉與調光簾，再依遮光、清潔、木質感與安裝條件收斂到 1 到 2 個方案。'
      }
    },
    {
      '@type': 'Question',
      name: '百葉窗價格試算要先比較哪些品項？',
      acceptedAnswer: {
        '@type': 'Answer',
        text: '建議先用同一尺寸比較鋁百葉、實木百葉與風琴簾，再依防潮、木質感、隔熱與安裝條件判斷最適合的方案。'
      }
    },
    {
      '@type': 'Question',
      name: '估價結果會包含安裝費嗎？',
      acceptedAnswer: {
        '@type': 'Answer',
        text: '會。系統會依品項規則估算材料費與安裝費，並回傳總價。'
      }
    },
    {
      '@type': 'Question',
      name: '三重窗簾價格試算後如何比價最有效率？',
      acceptedAnswer: {
        '@type': 'Answer',
        text: '建議固定同一尺寸比較捲簾、調光簾、實木百葉窗三個品項，再從三重窗簾服務頁預約丈量，能最快確認正式報價。'
      }
    },
    {
      '@type': 'Question',
      name: '窗簾價格試算要先看價格指南還是直接輸入尺寸？',
      acceptedAnswer: {
        '@type': 'Answer',
        text: '如果已經有寬高尺寸，可直接用本頁線上估價；若還在比款式，可先看 2026 窗簾價格指南，再回來用同尺寸比較各品項。'
      }
    },
    {
      '@type': 'Question',
      name: '窗簾價格試算怎麼判斷合理？',
      acceptedAnswer: {
        '@type': 'Answer',
        text: '建議用同一組尺寸比較 2 到 3 種品項，並同時看材料、基本安裝費、窗型與丈量條件。線上估價適合先抓合理區間，正式報價仍以現場丈量為準。'
      }
    },
    {
      '@type': 'Question',
      name: '實木百葉窗價格試算適合從哪裡開始？',
      acceptedAnswer: {
        '@type': 'Answer',
        text: '建議先切到木百葉品項並套用三重或台北區域，再到實木百葉產品頁確認木種、葉片與安裝條件。'
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
