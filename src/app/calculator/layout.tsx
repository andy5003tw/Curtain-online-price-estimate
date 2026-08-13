import type { Metadata } from 'next';
import React from 'react';
import { absoluteUrl, buildOgTwitterMeta } from '@/lib/seo';
import { calculatorFaq } from '@/data/calculatorFaq';

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
  '@type': 'WebApplication',
  '@id': `${absoluteUrl('/calculator/')}#web-application`,
  name: '宏森窗簾線上估價系統',
  applicationCategory: 'BusinessApplication',
  operatingSystem: 'Any',
  url: absoluteUrl('/calculator/'),
  description: '宏森窗簾計算機可快速完成窗簾價格試算與窗簾線上估價，輸入尺寸即可比較百葉窗、實木百葉、捲簾、調光簾與安裝預算。'
};

const faqSchema = {
  '@context': 'https://schema.org',
  '@type': 'FAQPage',
  mainEntity: calculatorFaq.map(item => ({
    '@type': 'Question',
    name: item.q,
    acceptedAnswer: { '@type': 'Answer', text: item.a },
  })),
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
