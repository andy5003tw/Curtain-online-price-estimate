import Link from 'next/link';
import type { ReactNode } from 'react';
import { ArrowRight } from 'lucide-react';
import { withBasePath } from '@/lib/base-path';

type HeroAction = {
  href: string;
  label: string;
};

type EditorialLandingHeroProps = {
  eyebrow: string;
  eyebrowIcon?: ReactNode;
  title: string;
  description: string;
  descriptionAiAnswer?: boolean;
  theme: 'about' | 'products' | 'cases' | 'blog' | 'calculator' | 'location' | 'taipei' | 'new-taipei';
  desktopImage: string;
  mobileImage: string;
  imageAlt: string;
  primaryAction: HeroAction;
  secondaryAction: HeroAction;
};

export default function EditorialLandingHero({
  eyebrow,
  eyebrowIcon,
  title,
  description,
  descriptionAiAnswer = false,
  theme,
  desktopImage,
  mobileImage,
  imageAlt,
  primaryAction,
  secondaryAction,
}: EditorialLandingHeroProps) {
  return (
    <section className={`editorial-landing-hero editorial-landing-hero--${theme}`} aria-labelledby={`${theme}-hero-title`}>
      <picture className="editorial-landing-hero__visual">
        <source media="(max-width: 640px)" srcSet={withBasePath(mobileImage)} />
        <img src={withBasePath(desktopImage)} alt={imageAlt} fetchPriority="high" />
      </picture>
      <div className="section-container editorial-landing-hero__inner">
        <div className="editorial-landing-hero__copy">
          <div className="editorial-landing-hero__content">
            <p className="editorial-landing-hero__eyebrow">{eyebrowIcon}{eyebrow}</p>
            <h1 id={`${theme}-hero-title`}>{title}</h1>
            <p className="editorial-landing-hero__description" data-ai-answer={descriptionAiAnswer ? 'true' : undefined}>{description}</p>
          </div>
          <div className="editorial-landing-hero__actions">
            <Link href={primaryAction.href} className="editorial-landing-hero__primary">
              {primaryAction.label} <ArrowRight size={18} aria-hidden="true" />
            </Link>
            <Link href={secondaryAction.href} className="editorial-landing-hero__secondary">
              {secondaryAction.label}
            </Link>
          </div>
        </div>
      </div>
    </section>
  );
}
