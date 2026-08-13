import { absoluteUrl } from '@/lib/seo';

export const businessEvidence = {
  schemaVersion: 1,
  reviewedAt: '2026-08-12',
  companyEntity: {
    id: `${absoluteUrl('/')}#localBusiness`,
    legalName: '宏森開發有限公司',
    telephone: '+886-2-8972-7322',
    address: '新北市三重區仁愛街125巷89號1樓',
    source: 'site-wide contact record',
  },
  publishingRules: {
    testimonials: 'blocked_without_source_url_or_receipt',
    aggregateRatings: 'blocked_without_review_platform_provenance',
    installationCounts: 'blocked_without_auditable_record',
    certifications: 'material_specific_document_required',
    warranties: 'written_quote_or_policy_required',
    serviceAreaPages: 'single_company_entity_only',
  },
} as const;
