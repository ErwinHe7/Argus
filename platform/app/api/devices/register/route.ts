import { NextResponse } from 'next/server';
import { z } from 'zod';
import { getCurrentUser } from '@/lib/auth';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

const DeviceRegistrationSchema = z.object({
  platform: z.literal('ios'),
  token: z.string().min(10).max(512),
  userId: z.string().optional(),
});

export async function POST(req: Request) {
  const user = await getCurrentUser();
  if (!user.authenticated) return NextResponse.json({ error: 'sign in required' }, { status: 401 });

  const json = await req.json().catch(() => null);
  const parsed = DeviceRegistrationSchema.safeParse(json);
  if (!parsed.success) return NextResponse.json({ error: 'invalid device registration' }, { status: 400 });

  return NextResponse.json({
    ok: true,
    registered: false,
    platform: parsed.data.platform,
    userId: user.id,
    message: 'Device token received. APNs persistence is pending Apple Developer configuration.',
  });
}
