import type { MetadataRoute } from 'next';

export default function robots(): MetadataRoute.Robots {
  const siteUrl = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://axio7.com';

  return {
    rules: {
      userAgent: '*',
      allow: ['/', '/pricing', '/research/sector-rotation', '/support', '/terms', '/privacy', '/refund-policy', '/refunds'],
      disallow: [
        '/admin',
        '/api',
        '/account',
        '/auth',
        '/billing',
        '/checkout',
        '/profile',
        '/settings',
      ],
    },
    sitemap: `${siteUrl}/sitemap.xml`,
    host: siteUrl,
  };
}
