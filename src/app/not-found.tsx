import type { Metadata } from 'next';
import Link from 'next/link';

export const metadata: Metadata = {
  title: '404 - 頁面不存在',
  description: '找不到您要查看的頁面，請返回首頁。',
};

export default function NotFound() {
  return (
    <div style={{ textAlign: 'center', padding: '8rem 1.5rem' }}>
      <p style={{ fontSize: '5rem', fontWeight: 900, color: 'var(--stone-200)', lineHeight: 1 }}>404</p>
      <h1 style={{ fontSize: '1.75rem', fontWeight: 700, marginBottom: '1rem', marginTop: '1rem' }}>找不到此頁面</h1>
      <p style={{ color: 'var(--stone-500)', marginBottom: '2rem' }}>您要找的頁面可能已移動或不存在，請點選下方按鈕返回首頁。</p>
      <div style={{ display: 'flex', gap: '0.75rem', justifyContent: 'center' }}>
        <Link href="/" className="btn-primary">返回首頁</Link>
        <Link href="/products" className="btn-outline">查看所有產品</Link>
      </div>
    </div>
  );
}
