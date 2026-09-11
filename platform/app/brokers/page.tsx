import type { Metadata } from 'next';
import { getBrokerageProviderCatalog } from '../../../ritual-investing-api/src/domains/brokerage-providers/catalog';
import { InvestingWorkspace } from '@/components/investing/InvestingHeader';
import { BrokerConnections } from '@/components/investing/BrokerConnections';
import { PersonalBroker } from '@/components/investing/PersonalBroker';

export const metadata: Metadata = { title: 'Broker connections · Leo', description: 'IBKR, moomoo and Webull connection setup for U.S. accounts.' };
export default function BrokersPage({ searchParams }: { searchParams: { symbol?: string } }) {
  const raw = searchParams.symbol;
  const symbol = typeof raw === 'string' && /^[A-Za-z0-9][A-Za-z0-9.$^+\-/= ]{0,13}$/.test(raw) ? raw : null;
  const personal = process.env.NODE_ENV === 'development' && process.env.LEO_PERSONAL_TRADING_ENABLED === 'true';
  return <InvestingWorkspace active="brokers">{personal ? <PersonalBroker symbol={symbol} /> : <BrokerConnections catalog={getBrokerageProviderCatalog()} symbol={symbol} />}</InvestingWorkspace>;
}
