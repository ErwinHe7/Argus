import { NextResponse } from 'next/server';

export const runtime = 'nodejs';

const PROVIDER_DEFS = [
  {
    id: 'auto',
    name: 'Auto Best',
    tag: 'recommended',
    description: 'Tries all configured providers and picks the best result automatically.',
    requiresKey: null,
  },
  {
    id: 'removebg',
    name: 'remove.bg',
    tag: 'best hair',
    description: 'Best for portraits, hair detail, and ID-photo style backgrounds.',
    requiresKey: 'REMOVEBG_API_KEY',
  },
  {
    id: 'photoroom',
    name: 'Photoroom',
    tag: 'ID photos',
    description: 'Strong for people, products, and mixed objects. Good fallback.',
    requiresKey: 'PHOTOROOM_API_KEY',
  },
  {
    id: 'clipdrop',
    name: 'Clipdrop',
    tag: 'fast',
    description: 'Fast alternative background removal model.',
    requiresKey: 'CLIPDROP_API_KEY',
  },
] as const;

export async function GET() {
  const providers = PROVIDER_DEFS.map((p) => ({
    id: p.id,
    name: p.name,
    tag: p.tag,
    description: p.description,
    available: p.requiresKey === null ? true : !!process.env[p.requiresKey],
    recommended: p.id === 'auto',
  }));

  // Auto is available if at least one real provider is configured
  const anyReal = providers.some((p) => p.id !== 'auto' && p.available);
  providers[0].available = anyReal;

  return NextResponse.json({ providers });
}
