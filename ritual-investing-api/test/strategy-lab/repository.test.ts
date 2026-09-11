import {describe,it,expect} from "vitest";
import type {DatabasePool} from "../../src/db/database-port.ts";
import {createStrategyRepository} from "../../src/domains/strategy-lab/repository.ts";
import {createStrategyApp} from "../../src/domains/strategy-lab/app.ts";
import type {VerifiedSupabasePrincipal} from "../../src/retained-app.ts";

const verified:VerifiedSupabasePrincipal={userId:"11111111-1111-4111-8111-111111111111",sessionId:"22222222-2222-4222-8222-222222222222",aal:"aal1",issuedAt:1_789_100_000,authenticatedAt:1_789_099_900};
function fixture(live=true){
 const calls:{text:string;values:readonly unknown[]}[]=[];let released=false;
 const pool:DatabasePool={connect:async()=>({query:async<Row>(text:string,values:readonly unknown[]=[])=>{calls.push({text,values});return {rows:(text.includes("strategy_has_live_session")?[{live}]:[]) as Row[]};},release:()=>{released=true;}}),end:async()=>{}};
 const repository=createStrategyRepository(pool);
 const app=createStrategyApp({repository,verifyAccessToken:async()=>verified,origins:["https://leo.axio7.workers.dev"],rateLimit:{allow:async()=>({allowed:true})}});
 return {calls,repository,app,released:()=>released};
}

describe("strategy repository verified-identity projection",()=>{
 it("accepts the real verifier's timestamp claims while installing only verified database identity",async()=>{
  const f=fixture();const response=await f.app.request("/v1/status",{headers:{authorization:"Bearer verified-fixture"}});
  expect(response.status).toBe(200);
  expect(await response.json()).toMatchObject({data:{membership:{userId:verified.userId,status:"active"}}});
  const context=f.calls.find(c=>c.text.includes("install_request_context"));
  expect(context?.values).toEqual([verified.userId,verified.sessionId,verified.aal]);
  expect(f.calls.some(c=>c.text==="set local role argus_member")).toBe(true);
  expect(f.calls.at(-1)?.text).toBe("commit");expect(f.released()).toBe(true);
 });
 it("still rejects malformed session identity before opening a database transaction",async()=>{
  const f=fixture();await expect(f.repository.transact({...verified,sessionId:"invalid"},async()=>null)).rejects.toThrow();expect(f.calls).toEqual([]);
 });
 it("still rejects a revoked session and rolls back the member transaction",async()=>{
  const f=fixture(false);const response=await f.app.request("/v1/status",{headers:{authorization:"Bearer verified-fixture"}});
  expect(response.status).toBe(401);expect(f.calls.at(-1)?.text).toBe("rollback");expect(f.released()).toBe(true);
 });
});
