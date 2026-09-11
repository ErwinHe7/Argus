import React from 'react';
import type { DeploymentMandate, EvidenceEvent } from '../../../ritual-investing-api/src/domains/strategy-lab/contracts';
import { accountEvidence, safeValue } from './state';
import { displayTime } from './catalog';

function rows(value: unknown): Record<string,unknown>[] {
  return Array.isArray(value) ? value.filter((row): row is Record<string,unknown> => Boolean(row && typeof row === 'object' && !Array.isArray(row))) : [];
}

export function AccountEvidence({deployments, events, stale}: {deployments:DeploymentMandate[];events:EvidenceEvent[];stale:boolean}) {
  return <>{deployments.map(deployment => {
    const {values, retained}=accountEvidence(events,deployment.id);
    const payload=values?.payload;
    const positions=rows(payload?.positions),orders=rows(payload?.pendingOrders);
    return <section className="strategy-account" key={deployment.id} aria-label={`${deployment.accountId} reported account state`}>
      <header><h3>{deployment.accountId}<span>{deployment.mode === 'paper' ? 'Paper account' : 'Dry run'}</span></h3><p>{stale || retained ? 'Last verified values · ' : 'Reported '} {displayTime(values?.occurredAt)}</p></header>
      <dl className="strategy-account-totals"><dt>Equity (USD)</dt><dd>{safeValue(payload?.equity)}</dd><dt>Drawdown (%)</dt><dd>{safeValue(payload?.drawdownPercent)}</dd></dl>
      <div className="strategy-account-tables"><div><h4>Positions</h4>{!payload || !Array.isArray(payload.positions) ? <p className="strategy-muted">Positions not reported</p> : positions.length === 0 ? <p className="strategy-muted">No positions in this report</p> : <div className="strategy-table-scroll" tabIndex={0} role="region" aria-label="Reported positions"><table><thead><tr><th>Symbol</th><th>Shares</th><th>Unrealized P&amp;L</th><th>Local stop</th></tr></thead><tbody>{positions.map((row,index)=><tr key={index}><td>{safeValue(row.symbol)}</td><td>{safeValue(row.quantity)}</td><td>{safeValue(row.unrealizedPnl)}</td><td>{safeValue(row.stopPrice)}</td></tr>)}</tbody></table></div>}</div>
      <div><h4>Pending orders</h4>{!payload || !Array.isArray(payload.pendingOrders) ? <p className="strategy-muted">Working orders not reported</p> : orders.length === 0 ? <p className="strategy-muted">No working orders in this report</p> : <div className="strategy-table-scroll" tabIndex={0} role="region" aria-label="Reported working orders"><table><thead><tr><th>Symbol</th><th>Side</th><th>Filled / ordered</th><th>Status</th></tr></thead><tbody>{orders.map((row,index)=><tr key={index}><td>{safeValue(row.symbol)}</td><td>{safeValue(row.side)}</td><td>{safeValue(row.filledQuantity)} / {safeValue(row.quantity)}</td><td>{safeValue(row.status)}</td></tr>)}</tbody></table></div>}</div></div>
    </section>;
  })}</>;
}
