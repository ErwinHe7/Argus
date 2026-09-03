-- Store private contact details needed to connect Trade buyers and sellers by email.

alter table public.listings
  add column if not exists seller_email text,
  add column if not exists seller_contact text;

alter table public.bids
  add column if not exists bidder_email text,
  add column if not exists bidder_contact text;

alter table public.transactions
  add column if not exists seller_email text,
  add column if not exists buyer_email text,
  add column if not exists seller_contact text,
  add column if not exists buyer_contact text;

create index if not exists listings_seller_email_idx on public.listings (seller_email);
create index if not exists bids_bidder_email_idx on public.bids (bidder_email);
