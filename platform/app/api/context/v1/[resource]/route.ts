import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import {
  buildPublicContextCatalog,
  fetchSecPublicContext,
  licenseBlockedResponse,
  PublicContextError,
} from '@/lib/public-context';
import {
  fetchPublicMacroContext,
  PUBLIC_MACRO_SERIES,
} from '@/lib/public-macro';
import {
  checkRateLimit,
  rateLimitKey,
} from '@/lib/market-intelligence/rate-limit';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export const maxDuration = 20;

const ROUTE = '/api/context/v1';
const resourceSchema = z.enum([
  'sources',
  'sec',
  'macro',
  'occ-open-interest',
  'news',
]);
const emptyQuerySchema = z.object({}).strict();
const secQuerySchema = z
  .object({
    symbol: z
      .string()
      .trim()
      .toUpperCase()
      .regex(/^[A-Z][A-Z0-9.-]{0,9}$/),
    limit: z.coerce.number().int().min(1).max(20).default(10),
  })
  .strict();
const macroQuerySchema = z
  .object({
    series: z
      .string()
      .trim()
      .min(1)
      .default('CPI_US_ALL_SA,UNEMPLOYMENT_RATE_US,PAYROLL_EMPLOYMENT_US,UST_CMT_2Y,UST_CMT_10Y,UST_10Y2Y_SPREAD,EFFR'),
  })
  .strict();
const newsQuerySchema = z
  .object({
    symbol: z
      .string()
      .trim()
      .toUpperCase()
      .regex(/^[A-Z][A-Z0-9.-]{0,9}$/)
      .optional(),
  })
  .strict();

type RouteContext = {
  params: {
    resource: string;
  };
};

export async function GET(req: NextRequest, context: RouteContext) {
  const rate = checkRateLimit(rateLimitKey(req, ROUTE), 30, 60_000);
  if (!rate.allowed) {
    return json(
      {
        schema_version: 'axio.public-context.v1',
        error: {
          code: 'RATE_LIMITED',
          message: 'Public context rate limit reached.',
        },
      },
      429,
      'no-store',
      {
        'Retry-After': String(rate.resetSeconds),
      }
    );
  }

  try {
    const resource = resourceSchema.parse(context.params.resource);
    const query = Object.fromEntries(req.nextUrl.searchParams.entries());

    if (resource === 'sources') {
      emptyQuerySchema.parse(query);
      const configuredOrigin =
        process.env.AXIO7_SITE_URL ||
        process.env.NEXT_PUBLIC_SITE_URL ||
        'https://axio7.com';
      return json(
        buildPublicContextCatalog(configuredOrigin),
        200,
        'public, max-age=60, s-maxage=120',
        {
          'X-RateLimit-Remaining': String(rate.remaining),
        }
      );
    }

    if (resource === 'sec') {
      const input = secQuerySchema.parse(query);
      const report = await fetchSecPublicContext(input.symbol, input.limit);
      return json(report, 200, 'public, max-age=60, s-maxage=120', {
        'X-RateLimit-Remaining': String(rate.remaining),
      });
    }

    if (resource === 'macro') {
      const input = macroQuerySchema.parse(query);
      const series = input.series.split(',').map((value) => value.trim());
      if (series.length > PUBLIC_MACRO_SERIES.length) {
        throw new PublicContextError(
          'TOO_MANY_SERIES',
          `At most ${PUBLIC_MACRO_SERIES.length} allowlisted public macro series may be requested.`,
          400
        );
      }
      const report = await fetchPublicMacroContext(series);
      return json(report, 200, 'no-store', {
        'X-Axio7-Context-Status': 'official-public-data',
        'X-RateLimit-Remaining': String(rate.remaining),
      });
    }

    if (resource === 'occ-open-interest') {
      emptyQuerySchema.parse(query);
      return json(
        licenseBlockedResponse(resource),
        503,
        'no-store',
        {
          'X-Axio7-Context-Status': 'license-required',
          'X-RateLimit-Remaining': String(rate.remaining),
        }
      );
    }

    newsQuerySchema.parse(query);
    return json(licenseBlockedResponse(resource), 503, 'no-store', {
      'X-Axio7-Context-Status': 'license-required',
      'X-RateLimit-Remaining': String(rate.remaining),
    });
  } catch (error) {
    if (error instanceof z.ZodError) {
      return json(
        {
          schema_version: 'axio.public-context.v1',
          error: {
            code: 'INVALID_QUERY',
            message: 'The context request contains an invalid or unknown field.',
            fields: error.issues.map((issue) => ({
              path: issue.path.join('.'),
              code: issue.code,
            })),
          },
        },
        400,
        'no-store'
      );
    }

    if (error instanceof PublicContextError) {
      return json(
        {
          schema_version: 'axio.public-context.v1',
          error: {
            code: error.code,
            message: error.message,
            ...(error.details ? { details: error.details } : {}),
          },
        },
        error.status,
        'no-store',
        {
          'X-Axio7-Context-Status': 'unavailable',
        }
      );
    }

    console.error(
      '[/api/context/v1]',
      error instanceof Error ? error.name : 'UnknownError'
    );
    return json(
      {
        schema_version: 'axio.public-context.v1',
        error: {
          code: 'DATA_UNAVAILABLE',
          message: 'Official context is unavailable.',
        },
      },
      503,
      'no-store'
    );
  }
}

function json(
  body: unknown,
  status: number,
  cacheControl: string,
  headers: Record<string, string> = {}
) {
  return NextResponse.json(body, {
    status,
    headers: {
      'Cache-Control': cacheControl,
      'X-Content-Type-Options': 'nosniff',
      ...headers,
    },
  });
}
