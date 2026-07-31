import { PostHog } from 'posthog-node';

let posthog: PostHog | null = null;

function getPostHog(): PostHog | null {
  if (posthog) return posthog;
  const key = process.env.NEXT_PUBLIC_POSTHOG_KEY;
  if (!key) return null;
  posthog = new PostHog(key, {
    host: process.env.NEXT_PUBLIC_POSTHOG_HOST || 'https://app.posthog.com',
    flushAt: 1,
    flushInterval: 0,
  });
  return posthog;
}

type ServerEvent =
  | {
      event: 'user_signed_up';
      properties: {
        user_id: string;
        signup_method: 'google' | 'apple' | 'magic_link' | 'oauth' | string;
        utm_source?: string;
        utm_medium?: string;
        utm_campaign?: string;
        utm_content?: string;
        utm_term?: string;
        referrer_host?: string;
        landing_path?: string;
      };
    }
  | {
      event: 'agents_responded';
      properties: {
        post_id: string;
        user_id: string;
        routing_mode?: 'single' | 'panel';
        agents_succeeded: number;
        agents_failed: number;
        total_latency_ms: number;
        total_cost_usd: number;
      };
    };

export function trackServerEvent(userId: string, ev: ServerEvent): void {
  const ph = getPostHog();
  if (!ph) return;
  try {
    ph.capture({ distinctId: userId, event: ev.event, properties: ev.properties });
  } catch (err) {
    console.warn('[posthog] server capture failed', err);
  }
}
