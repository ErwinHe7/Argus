export const LEO_GOOGLE_ANALYTICS_ID = 'G-07JFEYSPTV';

export function getGoogleAnalyticsId() {
  const configuredId = process.env.NEXT_PUBLIC_GA_ID?.trim();
  return configuredId && /^G-[A-Z0-9]+$/.test(configuredId)
    ? configuredId
    : LEO_GOOGLE_ANALYTICS_ID;
}
