import { NextResponse } from 'next/server';
import { getCurrentUser } from '@/lib/auth';
import { createPaddleRefundRequest } from '@/lib/refund-requests';
import { hasTrustedPostOrigin, requestBaseUrl } from '@/lib/stripe';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

function billingRedirect(request: Request, refund: 'requested' | 'unavailable') {
  const url = new URL('/billing', requestBaseUrl(request));
  url.searchParams.set('refund', refund);
  return NextResponse.redirect(url, 303);
}

export async function POST(request: Request) {
  const user = await getCurrentUser();
  if (!user.authenticated) {
    const signIn = new URL('/auth/signin', requestBaseUrl(request));
    signIn.searchParams.set('next', '/billing');
    return NextResponse.redirect(signIn, 303);
  }
  if (!hasTrustedPostOrigin(request)) {
    return NextResponse.json({ error: 'Invalid request origin.' }, { status: 403 });
  }

  try {
    const form = await request.formData();
    const reason = form.get('reason');
    if (typeof reason !== 'string') {
      return NextResponse.json({ error: 'A refund request reason is required.' }, { status: 400 });
    }
    await createPaddleRefundRequest({ userId: user.id, reason });
    return billingRedirect(request, 'requested');
  } catch (error) {
    console.error('[billing] Unable to create refund review request', error);
    return billingRedirect(request, 'unavailable');
  }
}
