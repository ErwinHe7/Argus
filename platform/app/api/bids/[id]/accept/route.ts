import { NextResponse } from 'next/server';
import { acceptBid, getBid, getListing } from '@/lib/store';
import { getCurrentUser } from '@/lib/auth';
import { sendTradeConnectionEmails } from '@/lib/trade-email';

export const runtime = 'nodejs';

export async function POST(_req: Request, { params }: { params: { id: string } }) {
  try {
    const bid = await getBid(params.id);
    if (!bid) return NextResponse.json({ error: 'bid not found' }, { status: 404 });
    const listing = await getListing(bid.listing_id);
    if (!listing) return NextResponse.json({ error: 'listing not found' }, { status: 404 });

    const user = await getCurrentUser();
    const ownsListing = listing.seller_id === user.id;
    const ownsEmail =
      Boolean(user.email && listing.seller_email) &&
      user.email!.toLowerCase() === listing.seller_email!.toLowerCase();

    if (!ownsListing && !ownsEmail) {
      return NextResponse.json({ error: 'only the seller can accept bids' }, { status: 403 });
    }

    const result = await acceptBid(params.id);
    if (!result) return NextResponse.json({ error: 'bid not acceptable' }, { status: 400 });
    const email = await sendTradeConnectionEmails(result);
    return NextResponse.json({ ...result, email });
  } catch (err: any) {
    return NextResponse.json({ error: err?.message ?? 'failed' }, { status: 500 });
  }
}
