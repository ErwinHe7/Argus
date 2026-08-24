import {
  dailyRitualPreviewSchema,
  publicCovenTeaserSchema,
  publicDiscoverItemSchema,
} from "./schemas.ts";

export const serializePublicDaily = (value: unknown) => dailyRitualPreviewSchema.parse(value);
export const serializePublicCoven = (value: unknown) => publicCovenTeaserSchema.parse(value);
export const serializePublicDiscover = (value: unknown) => publicDiscoverItemSchema.parse(value);
