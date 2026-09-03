export const ACQUISITION_ATTRIBUTION_COOKIE = 'axio7_acquisition_v1';

export type AcquisitionAttribution = {
  utm_source?: string;
  utm_medium?: string;
  utm_campaign?: string;
  utm_content?: string;
  utm_term?: string;
  referrer_host?: string;
  landing_path?: string;
};

const ATTRIBUTION_KEYS = [
  'utm_source',
  'utm_medium',
  'utm_campaign',
  'utm_content',
  'utm_term',
  'referrer_host',
  'landing_path',
] as const;

function clean(value: unknown, maximumLength: number): string | undefined {
  if (typeof value !== 'string') return undefined;
  const normalized = value.trim().replace(/[\u0000-\u001f\u007f]/g, '');
  return normalized ? normalized.slice(0, maximumLength) : undefined;
}

export function normalizeAcquisitionAttribution(
  input: Record<string, unknown>
): AcquisitionAttribution {
  const output: AcquisitionAttribution = {};
  for (const key of ATTRIBUTION_KEYS) {
    const value = clean(input[key], key === 'landing_path' ? 240 : 120);
    if (value) output[key] = value;
  }
  return output;
}

export function parseAcquisitionAttributionCookie(
  value: string | undefined
): AcquisitionAttribution {
  if (!value || value.length > 2_048) return {};
  try {
    const parsed = JSON.parse(decodeURIComponent(value)) as unknown;
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) return {};
    return normalizeAcquisitionAttribution(parsed as Record<string, unknown>);
  } catch {
    return {};
  }
}
