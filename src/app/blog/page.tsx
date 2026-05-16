import type { Metadata } from 'next';
import Link from 'next/link';
import { knowledgePosts, knowledgeCategories, knowledgeTags } from '@/data/knowledgePosts';
import BlogListClient from './BlogListClient';
import { absoluteUrl, buildOgTwitterMeta, COMPANY_NAME } from '@/lib/seo';

const BLOG_TITLE = '窗簾知識與挑選指南 | 宏森開發窗簾';
const BLOG_DESCRIPTION = '全台最完整的窗簾知識庫。包含13大類產品（捲簾、百葉、調光簾等）的挑選指南、材質分析、價格預算、尺寸測量與保養清洗。';

export const metadata: Metadata = {
  title: BLOG_TITLE,
  description: BLOG_DESCRIPTION,
  ...buildOgTwitterMeta({
    title: BLOG_TITLE,
    description: BLOG_DESCRIPTION,
    path: '/blog/',
    image: '/blog/price-guide-cover.webp',
    imageAlt: '窗簾知識與挑選指南',
  }),
};

const blogListSchema = {
  '@context': 'https://schema.org',
  '@type': 'Blog',
  name: '宏森開發窗簾知識專欄',
  url: absoluteUrl('/blog/'),
  blogPost: knowledgePosts.map(a => ({
    '@type': 'BlogPosting',
    headline: a.title,
    image: absoluteUrl(a.coverImage),
    description: a.description,
    datePublished: `${a.date}T08:00:00+08:00`,
    author: { 
      '@type': 'Organization', 
      name: COMPANY_NAME,
      url: absoluteUrl('/')
    },
    url: absoluteUrl(`/blog/${a.id}/`),
    mainEntityOfPage: { '@type': 'WebPage', '@id': absoluteUrl(`/blog/${a.id}/`) }
  })),
};

const breadcrumbSchema = {
  '@context': 'https://schema.org',
  '@type': 'BreadcrumbList',
  itemListElement: [
    { '@type': 'ListItem', position: 1, name: '首頁', item: absoluteUrl('/') },
    { '@type': 'ListItem', position: 2, name: '窗簾知識', item: absoluteUrl('/blog/') }
  ]
};

export default function BlogPage() {
  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(blogListSchema) }}
      />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(breadcrumbSchema) }}
      />

      <nav className="breadcrumb" aria-label="breadcrumb">
        <div className="breadcrumb-inner">
          <Link href="/">首頁</Link>
          <span>›</span>
          <span>窗簾知識</span>
        </div>
      </nav>

      <div className="page-hero">
        <div className="section-container">
          <div className="tag" style={{ background: 'rgba(255,255,255,0.1)', color: 'rgba(255,255,255,0.8)' }}>主題叢集知識庫</div>
          <h1 className="responsive-h1">窗簾選購指南・從挑選到保養</h1>
          <p className="responsive-p">30年窗簾專業知識大公開，幫助您精準挑選最合適的居家光影專家。</p>
        </div>
      </div>

      <BlogListClient 
        knowledgePosts={knowledgePosts} 
        knowledgeCategories={knowledgeCategories} 
        knowledgeTags={knowledgeTags} 
      />

      {/* Global CSS for text responsive sizing */}
      <style dangerouslySetInnerHTML={{__html: `
        .responsive-h1 { font-size: 2.5rem; }
        .responsive-p { font-size: 1.2rem; }
        @media (max-width: 768px) {
          .responsive-h1 { font-size: 1.8rem !important; }
          .responsive-p { font-size: 1rem !important; }
        }
      `}} />
    </>
  );
}
