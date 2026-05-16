import { MetadataRoute } from 'next';
import { products } from '@/data/products';
import { knowledgePosts } from '@/data/knowledgePosts';
import { pillarPages } from '@/data/pillarPages';
import { locationPages } from '@/data/locationPages';
import { absoluteUrl, productPath } from '@/lib/seo';

export const dynamic = 'force-static';

export default function sitemap(): MetadataRoute.Sitemap {
  const dateCandidates = [
    ...products.map(product => product.updatedAt),
    ...knowledgePosts.map(post => post.date),
    ...locationPages.map(page => page.lastModified),
  ].sort();
  const siteUpdatedAt = dateCandidates[dateCandidates.length - 1] || '2026-05-12';

  // Core static pages
  const staticPages = [
    '',
    '/about',
    '/location',
    '/products',
    '/calculator',
    '/cases',
    '/blog',
  ].map(route => ({
    url: absoluteUrl(route === '' ? '/' : `${route}/`),
    lastModified: siteUpdatedAt,
    changeFrequency: 'monthly' as const,
    priority: route === '' ? 1 : 0.8,
  }));

  // Dynamic product pages
  const productPages = products.map(product => ({
    url: absoluteUrl(productPath(product)),
    lastModified: product.updatedAt,
    changeFrequency: 'monthly' as const,
    priority: 0.85,
  }));

  const curtainPages = pillarPages.map(page => ({
    url: absoluteUrl(`/curtain/${page.id}/`),
    lastModified: siteUpdatedAt,
    changeFrequency: 'monthly' as const,
    priority: 0.75,
  }));

  const geoPages = locationPages.map(page => ({
    url: absoluteUrl(`/location/${page.id}/`),
    lastModified: page.lastModified,
    changeFrequency: 'monthly' as const,
    priority: 0.8,
  }));

  // Dynamic blog posts
  const blogPosts = knowledgePosts.map(post => ({
    url: absoluteUrl(`/blog/${post.id}/`),
    lastModified: post.date,
    changeFrequency: 'monthly' as const,
    priority: 0.6,
  }));

  return [...staticPages, ...productPages, ...curtainPages, ...geoPages, ...blogPosts];
}
