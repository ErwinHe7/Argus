import { NextResponse } from 'next/server';
import { z } from 'zod';
import { createBid, getListing } from '@/lib/store';
import { getCurrentUser } from '@/lib/auth';

export const runtime = 'nodejs';

const Input = z.object({
  listing_id: z.string().min(1),
  bidder_name: z.string().min(1).max(80),
  bidder_email: z.string().email().max(200).optional(),
  bidder_contact: z.string().max(200).optional(),
  amount_cents: z.number().int().positive(),
  message: z.string().max(1000).optional(),
});

export async function POST(req: Request) {
  const json = await req.json().catch(() => null);
  const parsed = Input.safeParse(json);
  if (!parsed.success) {
    return NextResponse.json({ error: 'invalid input' }, { status: 400 });
  }
  try {
    const user = await getCurrentUser();
    const listing = await getListing(parsed.data.listing_id);
    if (!listing || listing.status !== 'open') {
      return NextResponse.json({ error: 'listing not open or not found' }, { status: 400 });
    }
    if (listing.seller_id === user.id) {
      return NextResponse.json({ error: 'seller cannot bid on their own listing' }, { status: 400 });
    }
    const bidderEmail = parsed.data.bidder_email?.trim() || user.email;
    if (!bidderEmail) {
      return NextResponse.json({ error: 'buyer email is required' }, { status: 400 });
    }
    const bid = await createBid({
      listing_id: parsed.data.listing_id,
      bidder_id: user.id,
      bidder_name: parsed.data.bidder_name?.trim() || user.name,
      bidder_email: bidderEmail,
      bidder_contact: parsed.data.bidder_contact?.trim() || null,
      amount_cents: parsed.data.amount_cents,
      message: parsed.data.message ?? null,
    });
    if (!bid) {
      return NextResponse.json({ error: 'listing not open or not found' }, { status: 400 });
    }
    return NextResponse.json({ bid });
  } catch (err: any) {
    return NextResponse.json({ error: err?.message ?? 'failed' }, { status: 500 });
  }
}
