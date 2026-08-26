import { z } from "@hono/zod-openapi";

export const unsafeTextControls =
  /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F\u202A-\u202E\u2066-\u2069]/u;

export function hasSafeTextControls(value: string): boolean {
  return !unsafeTextControls.test(value);
}

export function boundedUserText(options: {
  maximum: number;
  minimum?: number;
  trim?: boolean;
}) {
  const base = options.trim === false ? z.string() : z.string().trim();
  return base
    .min(options.minimum ?? 1)
    .max(options.maximum)
    .refine(hasSafeTextControls, "unsafe Unicode controls are not allowed");
}
