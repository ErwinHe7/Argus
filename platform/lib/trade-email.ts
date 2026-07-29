import { formatCents } from './format';
import type { Listing, Transaction } from './types';

type SendResult = {
  ok: boolean;
  skipped: boolean;
  ids: string[];
  error?: string;
};

type TradeEmailInput = {
  listing: Listing;
  transaction: Transaction;
};

const RESEND_ENDPOINT = 'https://api.resend.com/emails';

function siteUrl() {
  return (process.env.NEXT_PUBLIC_SITE_URL ?? 'https://axio7.com').replace(/\/$/, '');
}

function fromAddress() {
  return process.env.EMAIL_FROM ?? 'AXIO7 Trade <onboarding@resend.dev>';
}

export function isTradeEmailConfigured() {
  return Boolean(process.env.RESEND_API_KEY);
}

function escapeHtml(value: string | null | undefined) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function line(label: string, value: string | null | undefined) {
  const trimmed = value?.trim();
  return trimmed ? `${label}: ${trimmed}` : `${label}: not provided`;
}

function htmlLine(label: string, value: string | null | undefined) {
  const trimmed = value?.trim();
  return `<p><strong>${escapeHtml(label)}:</strong> ${escapeHtml(trimmed || 'not provided')}</p>`;
}

function buildTextEmail({ listing, transaction }: TradeEmailInput) {
  const listingUrl = `${siteUrl()}/trade/${listing.id}`;
  return [
    `AXIO7 Trade introduction: ${listing.title}`,
    '',
    `Item: ${listing.title}`,
    `Deal amount: ${formatCents(transaction.amount_cents, listing.currency)}`,
    `Listing URL: ${listingUrl}`,
    '',
    'Seller',
    line('Name', transaction.seller_name),
    line('Email', transaction.seller_email),
    line('Contact', transaction.seller_contact),
    '',
    'Buyer',
    line('Name', transaction.buyer_name),
    line('Email', transaction.buyer_email),
    line('Contact', transaction.buyer_contact),
    '',
    'AXIO7 sent this introduction to both sides. Please confirm payment, pickup, delivery, and safety details directly with each other.',
  ].join('\n');
}

function buildHtmlEmail({ listing, transaction }: TradeEmailInput) {
  const listingUrl = `${siteUrl()}/trade/${listing.id}`;
  const price = formatCents(transaction.amount_cents, listing.currency);
  return `
    <div style="font-family: Inter, Arial, sans-serif; background:#f7f0e8; padding:28px;">
      <div style="max-width:640px; margin:0 auto; background:#ffffff; border:1px solid #e9ded4; padding:24px;">
        <p style="margin:0 0 8px; color:#d84727; font-size:12px; font-weight:700; letter-spacing:.08em; text-transform:uppercase;">AXIO7 Trade</p>
        <h1 style="margin:0 0 14px; color:#0a1520; font-size:24px; line-height:1.25;">You have a Trade introduction</h1>
        <p style="margin:0 0 18px; color:#4a4039;">AXIO7 sent this introduction to both sides so you can coordinate directly.</p>

        <div style="padding:16px; background:#f8f4ee; border:1px solid #eee2d7; margin-bottom:18px;">
          <p style="margin:0 0 6px; color:#0a1520;"><strong>Item:</strong> ${escapeHtml(listing.title)}</p>
          <p style="margin:0 0 6px; color:#0a1520;"><strong>Deal amount:</strong> ${escapeHtml(price)}</p>
          <p style="margin:0;"><a href="${escapeHtml(listingUrl)}" style="color:#d84727;">Open listing</a></p>
        </div>

        <div style="display:block; margin-bottom:16px;">
          <h2 style="margin:0 0 8px; color:#0a1520; font-size:16px;">Seller</h2>
          ${htmlLine('Name', transaction.seller_name)}
          ${htmlLine('Email', transaction.seller_email)}
          ${htmlLine('Contact', transaction.seller_contact)}
        </div>

        <div style="display:block; margin-bottom:18px;">
          <h2 style="margin:0 0 8px; color:#0a1520; font-size:16px;">Buyer</h2>
          ${htmlLine('Name', transaction.buyer_name)}
          ${htmlLine('Email', transaction.buyer_email)}
          ${htmlLine('Contact', transaction.buyer_contact)}
        </div>

        <p style="margin:0; color:#6f6258; font-size:13px;">Please confirm payment, pickup, delivery, and safety details directly.</p>
      </div>
    </div>
  `;
}

async function sendOneEmail(input: {
  to: string;
  subject: string;
  html: string;
  text: string;
  replyTo?: string | null;
  idempotencyKey: string;
}) {
  const apiKey = process.env.RESEND_API_KEY;
  if (!apiKey) throw new Error('RESEND_API_KEY is not configured');

  const res = await fetch(RESEND_ENDPOINT, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
      'Idempotency-Key': input.idempotencyKey,
    },
    body: JSON.stringify({
      from: fromAddress(),
      to: input.to,
      subject: input.subject,
      html: input.html,
      text: input.text,
      reply_to: input.replyTo ?? undefined,
    }),
  });

  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(data?.message ?? data?.error ?? `Email failed with ${res.status}`);
  }
  return data?.id ? String(data.id) : '';
}

export async function sendTradeConnectionEmails(input: TradeEmailInput): Promise<SendResult> {
  const sellerEmail = input.transaction.seller_email?.trim();
  const buyerEmail = input.transaction.buyer_email?.trim();

  if (!sellerEmail || !buyerEmail) {
    return {
      ok: false,
      skipped: true,
      ids: [],
      error: 'Buyer or seller email is missing.',
    };
  }

  if (!isTradeEmailConfigured()) {
    console.warn('[trade-email] RESEND_API_KEY is missing; skipping connection email.');
    return {
      ok: false,
      skipped: true,
      ids: [],
      error: 'RESEND_API_KEY is not configured.',
    };
  }

  const subject = `AXIO7 Trade match: ${input.listing.title}`;
  const html = buildHtmlEmail(input);
  const text = buildTextEmail(input);

  try {
    const [sellerId, buyerId] = await Promise.all([
      sendOneEmail({
        to: sellerEmail,
        subject,
        html,
        text,
        replyTo: buyerEmail,
        idempotencyKey: `trade-${input.transaction.id}-seller`,
      }),
      sendOneEmail({
        to: buyerEmail,
        subject,
        html,
        text,
        replyTo: sellerEmail,
        idempotencyKey: `trade-${input.transaction.id}-buyer`,
      }),
    ]);

    return { ok: true, skipped: false, ids: [sellerId, buyerId].filter(Boolean) };
  } catch (err: any) {
    console.error('[trade-email] Failed to send connection email:', err);
    return {
      ok: false,
      skipped: false,
      ids: [],
      error: err?.message ?? 'Email failed.',
    };
  }
}
