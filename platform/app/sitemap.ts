import type { MetadataRoute } from 'next';

export default function sitemap(): MetadataRoute.Sitemap {
  const siteUrl = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://axio7.com';
  const publicRoutes = [
    { path: '', priority: 1, changeFrequency: 'weekly' as const },
    { path: '/pricing', priority: 0.8, changeFrequency: 'monthly' as const },
    { path: '/support', priority: 0.5, changeFrequency: 'monthly' as const },
    { path: '/terms', priority: 0.4, changeFrequency: 'yearly' as const },
    { path: '/privacy', priority: 0.4, changeFrequency: 'yearly' as const },
    { path: '/refund-policy', priority: 0.4, changeFrequency: 'yearly' as const },
  ];

  return publicRoutes.map((route) => ({
    url: `${siteUrl}${route.path}`,
    lastModified: new Date(),
    changeFrequency: route.changeFrequency,
    priority: route.priority,
  }));
}
