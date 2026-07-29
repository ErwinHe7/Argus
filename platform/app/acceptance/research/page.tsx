import { notFound } from 'next/navigation';
import { AxioChat } from '@/components/AxioChat';

export const dynamic = 'force-dynamic';

/**
 * Browser-acceptance harness for the real paid research component.
 *
 * It is unreachable unless the server process is explicitly started with the
 * test-only flag. API routes remain independently authenticated, so this page
 * cannot grant research access in a deployed environment.
 */
export default function ResearchAcceptancePage() {
  if (process.env.AXIO7_UI_TEST_HARNESS !== 'true') notFound();

  return (
    <AxioChat
      initialUser={{
        authenticated: true,
        name: 'Acceptance User',
        email: 'acceptance@example.invalid',
        privateMarketDataAccess: false,
        researchAccess: true,
      }}
    />
  );
}
