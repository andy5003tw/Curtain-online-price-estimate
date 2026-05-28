import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { knowledgePosts, knowledgeCategories } from '@/data/knowledgePosts';
import { ChevronLeft, Calendar, Tag as TagIcon, Clock } from 'lucide-react';
import { absoluteUrl, buildOgTwitterMeta, COMPANY_NAME } from '@/lib/seo';
import { withBasePath, withBasePathInHtml } from '@/lib/base-path';

const PRICE_GUIDE_SNIPPET_VARIANTS = {
  A: {
    title: '2026 窗簾價格指南：1 分鐘看懂窗簾價格試算、三重窗簾比價與安裝費',
    description:
      '想做窗簾價格試算嗎？本文整理 2026 捲簾、鋁百葉、風琴簾、實木百葉窗價格試算與安裝費重點，並附三重窗簾比價流程。',
  },
  B: {
    title: '窗簾價格試算攻略：2026 三重窗簾比價、實木百葉窗價格與安裝費',
    description:
      '先做窗簾價格試算，再比三重窗簾與實木百葉窗價格。本文整理 2026 常見品項報價區間、安裝費與比價步驟。',
  },
} as const;

const BLOG_KNOWLEDGE_SUFFIX = ' | 宏森開發窗簾知識';

function resolveBlogSnippet(post: (typeof knowledgePosts)[number]) {
  if (post.id !== 'curtain-price-guide-2026') {
    return {
      title: post.title,
      description: post.description,
    };
  }

  const variant = process.env.SEO_SNIPPET_VARIANT === 'B' ? 'B' : 'A';
  return PRICE_GUIDE_SNIPPET_VARIANTS[variant];
}


export function generateStaticParams() {
  return knowledgePosts.map((post) => ({
    id: post.id,
  }));
}

export async function generateMetadata({ params }: { params: Promise<{ id: string }> }): Promise<Metadata> {
  const { id } = await params;
  const post = knowledgePosts.find((p) => p.id === id);
  if (!post) return { title: '找不到文章' };
  const snippet = resolveBlogSnippet(post);
  const metadataTitle = `${snippet.title}${BLOG_KNOWLEDGE_SUFFIX}`;

  return {
    title: metadataTitle,
    description: snippet.description,
    keywords: post.tags,
    ...buildOgTwitterMeta({
      title: metadataTitle,
      description: snippet.description,
      path: `/blog/${post.id}/`,
      image: post.coverImage,
      imageAlt: post.title,
      type: 'article',
    }),
  };
}

export default async function BlogPostPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const post = knowledgePosts.find((p) => p.id === id);
  if (!post) notFound();

  const categoryName = knowledgeCategories.find(c => c.id === post.category)?.name || '未分類';

  const articleSchema = {
    '@context': 'https://schema.org',
    '@type': 'Article',
    headline: post.title,
    description: post.description,
    datePublished: `${post.date}T08:00:00+08:00`,
    author: { 
      '@type': 'Organization', 
      name: COMPANY_NAME,
      url: absoluteUrl('/')
    },
    publisher: {
      '@type': 'Organization',
      name: COMPANY_NAME,
      logo: { '@type': 'ImageObject', url: absoluteUrl('/logo.webp') }
    },
    mainEntityOfPage: { '@type': 'WebPage', '@id': absoluteUrl(`/blog/${post.id}/`) },
    image: absoluteUrl(post.coverImage)
  };

  const faqSchema = post.faqs ? {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: post.faqs.map(faq => ({
      '@type': 'Question',
      name: faq.question,
      acceptedAnswer: {
        '@type': 'Answer',
        text: faq.answer
      }
    }))
  } : null;

  const breadcrumbSchema = {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: [
      { '@type': 'ListItem', position: 1, name: '首頁', item: absoluteUrl('/') },
      { '@type': 'ListItem', position: 2, name: '窗簾知識', item: absoluteUrl('/blog/') },
      { '@type': 'ListItem', position: 3, name: post.title, item: absoluteUrl(`/blog/${post.id}/`) },
    ],
  };

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(articleSchema) }}
      />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(breadcrumbSchema) }}
      />
      {faqSchema && (
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(faqSchema) }}
        />
      )}

      {/* Hero / Header */}
      <div style={{ background: 'var(--stone-900)', color: 'white', padding: '4rem 0 3rem' }}>
        <div className="section-container" style={{ maxWidth: '800px' }}>
          <Link href="/blog" className="hover-text-white" style={{ display: 'inline-flex', alignItems: 'center', color: 'var(--stone-400)', textDecoration: 'none', marginBottom: '2rem', fontSize: '0.9rem', transition: 'color 0.2s' }}>
            <ChevronLeft size={16} style={{ marginRight: '0.2rem' }} /> 返回知識庫
          </Link>
          
          <div style={{ display: 'flex', alignItems: 'center', gap: '1rem', marginBottom: '1rem', flexWrap: 'wrap' }}>
            <span style={{ background: 'var(--amber-600)', color: 'white', padding: '0.2rem 0.8rem', borderRadius: '2rem', fontSize: '0.85rem', fontWeight: 600 }}>{categoryName}</span>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', color: 'var(--stone-400)', fontSize: '0.85rem' }}>
              <Calendar size={14} /> {post.date}
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', color: 'var(--stone-400)', fontSize: '0.85rem' }}>
              <Clock size={14} /> 閱讀需 {post.readMin} 分鐘
            </div>
          </div>

          <h1 className="responsive-title" style={{ fontWeight: 700, lineHeight: 1.3, margin: '0 0 1.5rem', letterSpacing: '-0.02em' }}>{post.title}</h1>
          <p className="responsive-desc" style={{ color: 'var(--stone-300)', lineHeight: 1.6 }}>{post.description}</p>
        </div>
      </div>

      <article className="py-section bg-stone-50">
        <div className="section-container" style={{ maxWidth: '800px' }}>
          <div style={{ background: 'white', borderRadius: '1.5rem', overflow: 'hidden', border: '1px solid var(--stone-100)', boxShadow: '0 4px 20px rgba(0,0,0,0.03)' }}>
            
            {/* Visual Header Image Placeholder */}
            <div style={{ width: '100%', paddingTop: '50%', position: 'relative', background: 'var(--stone-100)' }}>
              <img 
                src={withBasePath(post.coverImage)} 
                alt={post.title} 
                style={{ position: 'absolute', top: 0, left: 0, width: '100%', height: '100%', objectFit: 'cover' }} 
              />
            </div>

            <div style={{ padding: '3rem 2.5rem' }}>
              <div 
                className="blog-content" 
                dangerouslySetInnerHTML={{ __html: withBasePathInHtml(post.contentHtml) }} 
                style={{ 
                  lineHeight: 1.8, 
                  color: 'var(--stone-700)', 
                  fontSize: '1.1rem' 
                }} 
              />

              {/* FAQ Section */}
              {post.faqs && post.faqs.length > 0 && (
                <div style={{ marginTop: '4rem', padding: '2rem', background: 'var(--stone-50)', borderRadius: '1rem' }}>
                  <h3 style={{ fontSize: '1.4rem', fontWeight: 700, color: 'var(--stone-900)', marginBottom: '1.5rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                    <span style={{ color: 'var(--amber-600)' }}>FAQ</span> 常見問與答
                  </h3>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
                    {post.faqs.map((faq, index) => (
                      <div key={index}>
                        <h4 style={{ fontSize: '1.1rem', fontWeight: 600, color: 'var(--stone-900)', marginBottom: '0.5rem' }}>Q: {faq.question}</h4>
                        <p style={{ fontSize: '1rem', color: 'var(--stone-600)', margin: 0 }}>A: {faq.answer}</p>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* Tags block in footer */}
              <div style={{ marginTop: '4rem', paddingTop: '2rem', borderTop: '1px solid var(--stone-100)' }}>
                <h4 style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', fontSize: '1rem', color: 'var(--stone-800)', marginBottom: '1rem' }}>
                  <TagIcon size={16} color="var(--amber-600)" /> 相關產品與分類標籤
                </h4>
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.6rem' }}>
                  {post.tags.map(tag => (
                    <Link key={tag} href={`/blog?tag=${tag}`} style={{ textDecoration: 'none' }}>
                      <span className="hover-tag-span" style={{ display: 'inline-block', background: 'var(--stone-50)', color: 'var(--stone-600)', padding: '0.5rem 1rem', borderRadius: '2rem', fontSize: '0.85rem', fontWeight: 500, border: '1px solid var(--stone-200)', transition: 'all 0.2s' }}>
                        {tag}
                      </span>
                    </Link>
                  ))}
                </div>
              </div>
            </div>
          </div>

          <div style={{ marginTop: '3rem', display: 'flex', justifyContent: 'center' }}>
            <Link href="/blog" className="btn-secondary hover-border-dark" style={{ display: 'inline-block', padding: '0.8rem 2rem', background: 'white', borderRadius: '2rem', border: '1px solid var(--stone-200)', color: 'var(--stone-700)', textDecoration: 'none', fontWeight: 600, transition: 'all 0.2s' }}>
              瀏覽更多知識文章
            </Link>
          </div>
        </div>
      </article>

      {/* Basic styles for HTML content parsed from dangerouslySetInnerHTML */}
      <style dangerouslySetInnerHTML={{__html: `
        .blog-content h2 { font-size: 1.6rem; font-weight: 700; color: var(--stone-900); margin: 2.5rem 0 1rem; position: relative; padding-left: 1rem; }
        .blog-content h2::before { content: ''; position: absolute; left: 0; top: 0.2rem; bottom: 0.2rem; width: 4px; background: var(--amber-500); border-radius: 4px; }
        .blog-content p { margin-bottom: 1.5rem; }
        .blog-content a { color: var(--amber-700); text-decoration: underline; text-decoration-color: var(--amber-200); text-underline-offset: 4px; transition: all 0.2s; font-weight: 600; }
        .blog-content a:hover { color: var(--amber-600); text-decoration-color: var(--amber-500); }
        .hover-text-white:hover { color: white !important; }
        .hover-border-dark:hover { border-color: var(--stone-400) !important; }
        .hover-tag-span:hover { background: var(--stone-200) !important; color: var(--stone-800) !important; }
        
        /* Responsive Typography */
        .responsive-title { font-size: 2.5rem; }
        .responsive-desc { font-size: 1.1rem; }
        @media (max-width: 768px) {
          .responsive-title { font-size: 1.8rem !important; }
          .responsive-desc { font-size: 1rem !important; }
          .blog-content { font-size: 1rem !important; }
          .blog-content h2 { font-size: 1.3rem !important; margin: 2rem 0 1rem; }
        }
      `}} />
    </>
  );
}
