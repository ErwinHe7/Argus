import type { DatabasePool } from "../../db/database-port.ts";
import { withMemberRequestTransaction } from "../../db/request-transaction.ts";
import { emptyWorkspace, StrategyError, type Principal, type StrategyRepository, type Workspace } from "./ports.ts";
import type { ConnectorDevice } from "./contracts.ts";
const collectionKinds={configurations:"configuration",deployments:"deployment",devices:"device",researchRuns:"research_run",evidence:"evidence",controls:"control",pairings:"pairing",idempotency:"idempotency",explanations:"explanation"} as const;
export function createStrategyRepository(pool:DatabasePool):StrategyRepository {
 return {
  async transact(principal,fn){
   // The shared JWT verifier also returns timing evidence. The strict database
   // boundary accepts only the already-verified identity/session claims.
   const verifiedClaims={userId:principal.userId,sessionId:principal.sessionId,aal:principal.aal};
   return withMemberRequestTransaction({pool,verifiedClaims},async db=>{
   const live=await db.query<{live:boolean}>("select argus_private.strategy_has_live_session() as live");
   if(live.rows[0]?.live!==true)throw new StrategyError(401,"session_inactive","Sign in again to access strategies.");
   await db.query("select pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('strategy:' || argus_private.trusted_request_user_id()::text,0))");
   // History is immutable and remains in PostgreSQL. Runtime reads are bounded;
   // currently owned mandates and their exact controls are never evicted by it.
   const result=await db.query<{kind:string;body:Record<string,unknown>}>(`with recent as (
    select selected.* from (values ('configuration',100),('deployment',20),('device',20),('research_run',100),('evidence',200),('control',200),('pairing',20),('explanation',20)) bounds(kind,cap)
    cross join lateral (select r.kind,r.body,r.created_at,r.id from argus_app.strategy_records r where r.owner_user_id=argus_private.trusted_request_user_id() and r.kind=bounds.kind order by r.created_at desc,r.id desc limit bounds.cap) selected
   ), current_mandates as (
    select r.kind,r.body,r.created_at,r.id from argus_app.strategy_records r where r.owner_user_id=argus_private.trusted_request_user_id() and r.kind='deployment' and (r.body->>'state'<>'retired' or r.body->>'retiredAcknowledgedAt' is null)
   ), current_controls as (
    select c.kind,c.body,c.created_at,c.id from argus_app.strategy_records c join current_mandates d on c.body->>'deploymentId'=d.id::text and c.body->>'mandateVersion'=d.body->>'mandateVersion' where c.owner_user_id=argus_private.trusted_request_user_id() and c.kind='control'
   ), latest_health as (
    select e.* from current_mandates d cross join (values ('heartbeat'),('reconciliation'),('incident')) kinds(event_kind)
    cross join lateral (select r.kind,r.body,r.created_at,r.id from argus_app.strategy_records r where r.owner_user_id=argus_private.trusted_request_user_id() and r.kind='evidence' and r.body->>'deploymentId'=d.id::text and r.body->>'kind'=kinds.event_kind order by r.created_at desc,r.id desc limit 1) e
   ), reports as (
    select r.kind,r.body,r.created_at,r.id from argus_app.strategy_records r join recent runs on runs.kind='research_run' and r.id::text=runs.body->>'evidenceEventId' where r.owner_user_id=argus_private.trusted_request_user_id() and r.kind='evidence'
   ) select distinct kind,body,created_at,id from (select * from recent union all select * from current_mandates union all select * from current_controls union all select * from latest_health union all select * from reports) records order by created_at,id`);
   const state=emptyWorkspace();const before=new Map<string,string>();
   for(const [collection,kind] of Object.entries(collectionKinds)){
    const rows=result.rows.filter(r=>r.kind===kind).map(r=>r.body);
    (state as unknown as Record<string,unknown>)[collection]=rows;
    for(const row of rows)before.set(`${kind}:${row.id}`,JSON.stringify(row));
   }
   state.lookupRecord=async(kind,id)=>{const result=await db.query<{body:unknown}>("select body from argus_app.strategy_records where owner_user_id=argus_private.trusted_request_user_id() and kind=$1 and id=$2::uuid",[kind,id]);return result.rows[0]?.body;};
   state.lookupSequence=async(deploymentId,sequence)=>{const result=await db.query<{body:unknown}>("select body from argus_app.strategy_records where owner_user_id=argus_private.trusted_request_user_id() and kind='evidence' and body->>'deploymentId'=$1 and body->>'sequence'=$2",[deploymentId,String(sequence)]);return result.rows[0]?.body;};
   const response=await fn(state);
   for(const [collection,kind] of Object.entries(collectionKinds))for(const row of state[collection as keyof typeof collectionKinds]){
    if(before.get(`${kind}:${row.id}`)===JSON.stringify(row))continue;
    await db.query("insert into argus_app.strategy_records(id,owner_user_id,tenant_id,lifecycle_id,kind,body) values ($1::uuid,argus_private.trusted_request_user_id(),argus_private.trusted_request_tenant_id(),argus_private.trusted_request_lifecycle_id(),$2,$3::jsonb) on conflict (owner_user_id,kind,id) do update set body=excluded.body",[row.id,kind,JSON.stringify(row)]);
   }
   return response;
  });},
  async pair(input){const client=await pool.connect();try{
   const result=await client.query<{device:ConnectorDevice}>("select argus_private.strategy_redeem_pairing($1,$2::uuid,$3,$4,$5,$6::timestamptz) as device",[input.pairingHash,input.deviceId,input.tokenHash,input.name,input.platform,input.now]);
   return result.rows[0]?.device??null;
  }finally{client.release();}},
  async authenticateDevice(deviceId,tokenHash){const client=await pool.connect();try{
   const result=await client.query<{user_id:string;session_id:string;aal:"aal1"|"aal2"}>("select * from argus_private.strategy_device_principal($1::uuid,$2)",[deviceId,tokenHash]);
   const row=result.rows[0];return row?{userId:row.user_id,sessionId:row.session_id,aal:row.aal}:null;
  }finally{client.release();}}
 };
}
