import { ZodError } from "zod";

import {
  marketMapHorizonSchema,
  marketMapSnapshotSchema,
} from "./schemas.ts";
import {
  MarketMapError,
  type MarketMapProvider,
  type MarketMapProviderRequest,
} from "./ports.ts";
import { uuidSchema } from "../retained-http/schemas.ts";

export const QUANT_MARKET_MAP_UPSTREAM_PATH = "/api/v1/research/market-map";
const maximumResponseBytes = 4 * 1024 * 1024;

function validatedOrigin(baseUrl: string): URL {
  let parsed: URL;
  try {
    parsed = new URL(baseUrl);
  } catch {
    throw new Error("invalid_market_map_quant_origin");
  }
  const loopback = parsed.hostname === "127.0.0.1" ||
    parsed.hostname === "localhost" || parsed.hostname === "[::1]";
  if ((parsed.protocol !== "https:" && !(parsed.protocol === "http:" && loopback)) ||
    parsed.username !== "" || parsed.password !== "" || parsed.search !== "" ||
    parsed.hash !== "" || (parsed.pathname !== "" && parsed.pathname !== "/")) {
    throw new Error("invalid_market_map_quant_origin");
  }
  return parsed;
}

function validatedServiceToken(token: string): string {
  if (token.length < 32 || token.length > 4_096 || token.trim() !== token ||
    /[\u0000-\u001f\u007f]/.test(token)) {
    throw new Error("invalid_market_map_quant_token");
  }
  return token;
}

function requestUrl(origin: URL, request: MarketMapProviderRequest): URL {
  const assetId = request.assetId === undefined ? undefined : uuidSchema.parse(request.assetId);
  const horizon = marketMapHorizonSchema.parse(request.horizon);
  const url = new URL(origin.origin);
  url.pathname = QUANT_MARKET_MAP_UPSTREAM_PATH +
    (assetId === undefined ? "" : `/${encodeURIComponent(assetId)}`);
  url.searchParams.set("horizon", horizon);
  return url;
}

export function createQuantMarketMapHttpAdapter(input: Readonly<{
  baseUrl: string;
  serviceToken: string;
  timeoutMilliseconds?: number;
  fetch?: typeof fetch;
}>): MarketMapProvider {
  const origin = validatedOrigin(input.baseUrl);
  const serviceToken = validatedServiceToken(input.serviceToken);
  const timeoutMilliseconds = input.timeoutMilliseconds ?? 4_000;
  const fetchImplementation = input.fetch ?? fetch;
  if (!Number.isInteger(timeoutMilliseconds) || timeoutMilliseconds < 100 ||
    timeoutMilliseconds > 30_000) {
    throw new Error("invalid_market_map_quant_timeout");
  }

  return Object.freeze({
    async read(request: MarketMapProviderRequest): Promise<unknown> {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), timeoutMilliseconds);
      try {
        const response = await fetchImplementation(requestUrl(origin, request), {
          method: "GET",
          headers: {
            accept: "application/json",
            "x-research-token": serviceToken,
          },
          redirect: "error",
          signal: controller.signal,
        });
      if (response.status === 404) {
        throw new MarketMapError("market_map_asset_not_found");
      }
      if (response.status === 403) {
        throw new MarketMapError("market_map_not_entitled");
      }
      if (!response.ok) {
        throw new MarketMapError("market_map_provider_unavailable");
      }
      const contentType = response.headers.get("content-type")
        ?.split(";", 1)[0]
        ?.trim()
        .toLowerCase();
      const declaredLength = Number(response.headers.get("content-length"));
      if (contentType !== "application/json" ||
        (Number.isFinite(declaredLength) && declaredLength > maximumResponseBytes)) {
        throw new MarketMapError("market_map_contract_invalid");
      }

      let raw: unknown;
      try {
        if (response.body === null) throw new MarketMapError("market_map_contract_invalid");
        const reader = response.body.getReader();
        const decoder = new TextDecoder("utf-8", { fatal: true });
        let bytes = 0;
        let body = "";
        try {
          while (true) {
            const chunk = await reader.read();
            if (chunk.done) break;
            bytes += chunk.value.byteLength;
            if (bytes > maximumResponseBytes) {
              await reader.cancel();
              throw new MarketMapError("market_map_contract_invalid");
            }
            body += decoder.decode(chunk.value, { stream: true });
          }
          body += decoder.decode();
        } finally {
          reader.releaseLock();
        }
        raw = JSON.parse(body) as unknown;
      } catch (error) {
        if (error instanceof MarketMapError) throw error;
        throw new MarketMapError("market_map_contract_invalid");
      }

      try {
        return marketMapSnapshotSchema.parse(raw);
      } catch (error) {
        if (error instanceof ZodError) {
          throw new MarketMapError("market_map_contract_invalid");
        }
        throw error;
      }
      } catch (error) {
        if (error instanceof MarketMapError) throw error;
        throw new MarketMapError("market_map_provider_unavailable");
      } finally {
        clearTimeout(timeout);
      }
    },
  });
}
