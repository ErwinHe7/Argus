import crypto from 'crypto';
import { supabaseAdmin, isSupabaseConfigured } from '@/lib/supabase';

export type BrokerKeyKind = 'alpaca' | 'ibkr';
export type BrokerEnv = 'paper' | 'live';

export type StoredBrokerKey = {
  userId: string;
  kind: BrokerKeyKind;
  env: BrokerEnv;
  payload: BrokerKeyPayload;
  createdAt: string;
};

export type BrokerKeyPayload =
  | { kind: 'alpaca'; apiKey: string; apiSecret: string }
  | { kind: 'ibkr'; baseUrl: string; accountId: string; sessionToken?: string };

const ALGO = 'aes-256-gcm';

function getMasterKey(): Buffer {
  const raw = process.env.BROKER_ENCRYPTION_KEY;
  if (!raw) {
    throw new Error(
      'BROKER_ENCRYPTION_KEY is not set. Generate with: node -e "console.log(require(\'crypto\').randomBytes(32).toString(\'base64\'))"'
    );
  }
  const key = Buffer.from(raw, 'base64');
  if (key.length !== 32) {
    throw new Error('BROKER_ENCRYPTION_KEY must be 32 bytes (base64-encoded).');
  }
  return key;
}

export function encryptPayload(payload: BrokerKeyPayload): string {
  const key = getMasterKey();
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv(ALGO, key, iv);
  const plaintext = Buffer.from(JSON.stringify(payload), 'utf8');
  const ciphertext = Buffer.concat([cipher.update(plaintext), cipher.final()]);
  const authTag = cipher.getAuthTag();
  return [
    iv.toString('base64'),
    authTag.toString('base64'),
    ciphertext.toString('base64'),
  ].join('.');
}

export function decryptPayload(blob: string): BrokerKeyPayload {
  const key = getMasterKey();
  const [ivB64, tagB64, ctB64] = blob.split('.');
  if (!ivB64 || !tagB64 || !ctB64) throw new Error('Invalid broker key payload.');
  const iv = Buffer.from(ivB64, 'base64');
  const authTag = Buffer.from(tagB64, 'base64');
  const ciphertext = Buffer.from(ctB64, 'base64');
  const decipher = crypto.createDecipheriv(ALGO, key, iv);
  decipher.setAuthTag(authTag);
  const plaintext = Buffer.concat([decipher.update(ciphertext), decipher.final()]);
  return JSON.parse(plaintext.toString('utf8')) as BrokerKeyPayload;
}

export async function saveBrokerKey(
  userId: string,
  kind: BrokerKeyKind,
  env: BrokerEnv,
  payload: BrokerKeyPayload
): Promise<void> {
  if (!isSupabaseConfigured()) throw new Error('Supabase not configured.');
  const blob = encryptPayload(payload);
  const sb = supabaseAdmin();
  const { error } = await sb.from('user_broker_keys').upsert(
    {
      user_id: userId,
      kind,
      env,
      encrypted_payload: blob,
      updated_at: new Date().toISOString(),
    },
    { onConflict: 'user_id,kind,env' }
  );
  if (error) throw new Error(`broker_keys upsert: ${error.message}`);
}

export async function loadBrokerKey(
  userId: string,
  kind: BrokerKeyKind,
  env: BrokerEnv
): Promise<BrokerKeyPayload | null> {
  if (!isSupabaseConfigured()) return null;
  const sb = supabaseAdmin();
  const { data, error } = await sb
    .from('user_broker_keys')
    .select('encrypted_payload')
    .eq('user_id', userId)
    .eq('kind', kind)
    .eq('env', env)
    .maybeSingle();
  if (error || !data?.encrypted_payload) return null;
  try {
    return decryptPayload(data.encrypted_payload);
  } catch (err) {
    console.warn('[broker-keys] decrypt failed', err);
    return null;
  }
}

export async function deleteBrokerKey(
  userId: string,
  kind: BrokerKeyKind,
  env: BrokerEnv
): Promise<void> {
  if (!isSupabaseConfigured()) return;
  const sb = supabaseAdmin();
  await sb.from('user_broker_keys').delete().eq('user_id', userId).eq('kind', kind).eq('env', env);
}

export async function listBrokerKeyStubs(
  userId: string
): Promise<Array<{ kind: BrokerKeyKind; env: BrokerEnv; updatedAt: string }>> {
  if (!isSupabaseConfigured()) return [];
  const sb = supabaseAdmin();
  const { data, error } = await sb
    .from('user_broker_keys')
    .select('kind, env, updated_at')
    .eq('user_id', userId);
  if (error || !data) return [];
  return data.map((row) => ({ kind: row.kind, env: row.env, updatedAt: row.updated_at }));
}
