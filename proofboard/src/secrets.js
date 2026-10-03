// AES-256-GCM encryption for stored Stripe keys, so hourly refreshes do not
// require keeping plaintext keys on disk.
import { createCipheriv, createDecipheriv, createHash, randomBytes } from 'node:crypto';

export function createSealer(appSecret) {
  if (typeof appSecret !== 'string' || appSecret.length < 32) {
    throw new Error('APP_SECRET must be set to at least 32 characters.');
  }
  const key = createHash('sha256').update(appSecret).digest();
  return {
    seal(plaintext) {
      const iv = randomBytes(12);
      const cipher = createCipheriv('aes-256-gcm', key, iv);
      const data = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
      return [iv, cipher.getAuthTag(), data].map((b) => b.toString('base64')).join('.');
    },
    open(sealed) {
      const [iv, tag, data] = sealed.split('.').map((part) => Buffer.from(part, 'base64'));
      const decipher = createDecipheriv('aes-256-gcm', key, iv);
      decipher.setAuthTag(tag);
      return Buffer.concat([decipher.update(data), decipher.final()]).toString('utf8');
    },
  };
}
