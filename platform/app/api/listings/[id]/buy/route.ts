import { NextResponse } from 'next/server';
import { z } from 'zod';
import { formatCents } from '@/lib/format';
import { acceptBid, createBid, createMessage, getListing, rollbackTradeConnection } from '@/lib/store';
import { getCurrentUser } from '@/lib/auth';
import { isTradeEmailConfigured, sendTradeConnectionEmails } from '@/lib/trade-email';

export const runtime = 'nodejs';

const Input = z.object({
  buyer_name: z.string().min(1).max(80),
  buyer_email: z.string().email().max(200).optional(),
  buyer_contact: z.string().max(200).optional(),
  amount_cents: z.number().int().positive().optional(),
  message: z.string().max(1000).optional(),
});

export async function POST(req: Request, { params }: { params: { id: string } }) {
  const json = await req.json().catch(() => null);
  const parsed = Input.safeParse(json);
  if (!parsed.success) {
    return NextResponse.json({ error: 'invalid input', detail: parsed.error.flatten() }, { status: 400 });
  }

  try {
    const listing = await getListing(params.id);
    if (!listing || listing.status !== 'open') {
      return NextResponse.json({ error: 'listing not open or not found' }, { status: 400 });
    }

    const user = await getCurrentUser();
    if (!user.authenticated || !user.email) {
      return NextResponse.json({ error: 'Please sign in with Google before connecting with the seller.' }, { status: 401 });
    }
    if (!listing.seller_email) {
      return NextResponse.json({ error: 'seller email is missing for this listing' }, { status: 400 });
    }
    if (listing.seller_id === user.id) {
      return NextResponse.json({ error: 'seller cannot buy their own listing' }, { status: 400 });
    }
    if (!isTradeEmailConfigured()) {
      return NextResponse.json({ error: 'Trade email is not configured yet. Set RESEND_API_KEY in Vercel first.' }, { status: 503 });
    }

    const bid = await createBid({
      listing_id: listing.id,
      bidder_id: user.id,
      bidder_name: parsed.data.buyer_name.trim() || user.name,
      // Buyer email is always taken from the authenticated account on the server.
      bidder_email: user.email,
      bidder_contact: parsed.data.buyer_contact?.trim() || null,
      amount_cents: parsed.data.amount_cents ?? listing.asking_price_cents,
      message: parsed.data.message?.trim() || 'Buyer clicked I want to buy.',
    });

    if (!bid) {
      return NextResponse.json({ error: 'could not create purchase offer' }, { status: 400 });
    }

    const result = await acceptBid(bid.id);
    if (!result) {
      return NextResponse.json({ error: 'could not create trade connection' }, { status: 400 });
    }

    const email = await sendTradeConnectionEmails({
      listing: result.listing,
      transaction: result.transaction,
    });

    if (!email.ok) {
      console.error('[trade-buy] email failed', {
        listingId: listing.id,
        skipped: email.skipped,
        error: email.error,
      });
      await rollbackTradeConnection({
        listingId: result.listing.id,
        bidId: bid.id,
        transactionId: result.transaction.id,
      }).catch((rollbackError) => {
        console.error('[trade-buy] rollback failed after email failure', {
          listingId: listing.id,
          error: rollbackError?.message ?? rollbackError,
        });
      });
      return NextResponse.json(
        {
          error: email.error ?? 'Trade email failed. Please try again.',
          bid,
          ...result,
          email,
        },
        { status: email.skipped ? 503 : 502 }
      );
    }

    // Post a system message to kick off the thread
    await createMessage({
      transaction_id: result.transaction.id,
      sender_id: 'system',
      sender_name: 'AXIO7',
      content: `Trade connection created for "${listing.title}" (${formatCents(listing.asking_price_cents, listing.currency)}). Both sides have been introduced by email. Use this thread to coordinate pickup, payment, and details.`,
    }).catch(() => {});

    const threadUrl = `/trade/${listing.id}/thread?tx=${result.transaction.id}`;
    return NextResponse.json({ bid, ...result, email, threadUrl });
  } catch (err: any) {
    console.error('[trade-buy] failed', {
      listingId: params.id,
      error: err?.message ?? err,
    });
    return NextResponse.json({ error: err?.message ?? 'failed' }, { status: 500 });
  }
}
