-- AXIO7 rebrand migration (up)
-- Run in Supabase SQL Editor to update existing seed data.

UPDATE public.posts
SET
  author_id   = 'axio7-seed',
  author_name = 'AXIO7',
  author_avatar = 'https://api.dicebear.com/9.x/bottts/svg?seed=axio7&backgroundColor=6366f1',
  content = replace(content, 'Aximoas', 'AXIO7')
WHERE author_id = 'aximoas-seed';

UPDATE public.listings
SET
  seller_id   = 'axio7-seed',
  seller_name = 'AXIO7 Team'
WHERE seller_id = 'aximoas-seed';

-- Down (rollback)
-- UPDATE public.posts SET author_id='aximoas-seed', author_name='Aximoas', author_avatar='https://api.dicebear.com/9.x/bottts/svg?seed=aximoas&backgroundColor=6366f1' WHERE author_id='axio7-seed';
-- UPDATE public.listings SET seller_id='aximoas-seed', seller_name='Aximoas Team' WHERE seller_id='axio7-seed';
