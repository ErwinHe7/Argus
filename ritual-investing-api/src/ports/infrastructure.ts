export type Clock = {
  now(): Date;
};

export type StorageObject = Readonly<{
  body: Uint8Array;
  contentType: string;
  etag?: string;
}>;

export interface StoragePort {
  get(key: string): Promise<StorageObject | null>;
  put(
    key: string,
    body: Uint8Array,
    options: Readonly<{ contentType: string; ifMatch?: string }>,
  ): Promise<Readonly<{ etag: string }>>;
  remove(key: string): Promise<void>;
}

export interface QueuePort<Message> {
  send(message: Message): Promise<void>;
  sendBatch(messages: readonly Message[]): Promise<void>;
}

export interface RateLimitPort {
  allow(
    key: string,
    policy: Readonly<{ limit: number; windowSeconds: number }>,
  ): Promise<Readonly<{ allowed: boolean; retryAfterSeconds?: number }>>;
}

export type RequestIdPort = {
  next(): string;
};
