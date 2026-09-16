import type { Metadata } from 'next';
import Link from 'next/link';
import { knowledgePosts, knowledgeCategories, knowledgeTags } from '@/data/knowledgePosts';
import BlogListClient from './BlogListClient';
import EditorialLandingHero from '@/components/EditorialLandingHero';
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

      <EditorialLandingHero
        theme="blog"
        eyebrow="窗簾知識庫・選購到保養"
        title="從問題開始，選到適合的窗簾"
        description="用空間、採光與預算，找到下一步該看的內容。"
        desktopImage="/nav-hero/blog-desktop.webp"
        mobileImage="/nav-hero/blog-mobile.webp"
        imageAlt="窗邊閱讀角與窗簾布樣的安靜居家情境"
        primaryAction={{ href: '#blog-topic-start', label: '從空間開始挑選' }}
        secondaryAction={{ href: '/blog/curtain-price-guide-2026/', label: '查看價格指南' }}
      />

      <section className="editorial-guide" aria-labelledby="blog-guide-heading">
        <div className="section-container editorial-guide__inner">
          <div className="editorial-guide__copy">
            <h2 id="blog-guide-heading">窗簾選購指南：挑選、材質、價格與保養</h2>
            <p>從客廳、臥室到浴室的需求開始，再看款式、尺寸、價格與清潔保養，讓選擇更有方向。</p>
          </div>
          <nav className="editorial-guide__links" aria-label="窗簾知識快速入口">
            <a href="#blog-topic-start">空間挑選指南</a>
            <a href="#blog-topic-start">款式與材質解析</a>
            <Link href="/blog/curtain-price-guide-2026/">預算與價格分析</Link>
            <a href="#blog-topic-start">保養與清潔技巧</a>
          </nav>
        </div>
      </section>

      <div id="blog-topic-start" className="section-anchor">
        <BlogListClient
          knowledgePosts={knowledgePosts}
          knowledgeCategories={knowledgeCategories}
          knowledgeTags={knowledgeTags}
        />
      </div>

      <section className="py-section bg-white" aria-labelledby="all-articles-heading">
        <div className="section-container">
          <div className="section-heading">
            <h2 id="all-articles-heading">所有窗簾知識文章</h2>
            <p>此清單提供不依賴篩選器的文章入口，方便讀者與搜尋引擎完整瀏覽知識庫。</p>
          </div>
          <ul style={{ display: 'grid', gap: '0.75rem', paddingLeft: '1.25rem' }}>
            {knowledgePosts.map(post => (
              <li key={post.id}>
                <Link href={`/blog/${post.id}/`}>{post.title}</Link>
              </li>
            ))}
          </ul>
        </div>
      </section>

    </>
  );
}
