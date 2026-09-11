import {afterAll,beforeAll,describe,expect,it} from "vitest";
import {readFile} from "node:fs/promises";
import pg from "pg";
import {createStrategyRepository} from "../../src/domains/strategy-lab/repository.ts";
import {createStrategyService} from "../../src/domains/strategy-lab/service.ts";
import type {Principal} from "../../src/domains/strategy-lab/ports.ts";
import type {DatabasePool} from "../../src/db/database-port.ts";

// Opt-in, disposable local PostgreSQL only. Never targets a configured app DB.
const url=process.env.STRATEGY_TEST_DATABASE_URL;
if(url&&!/^postgresql:\/\/postgres@127\.0\.0\.1:55443\/postgres$/.test(url))throw new Error("strategy_test_requires_disposable_local_database");
const suite=url?describe:describe.skip;
const owner:Principal={userId:"11111111-1111-4111-8111-111111111111",sessionId:"22222222-2222-4222-8222-222222222222",aal:"aal1"};
const other:Principal={userId:"33333333-3333-4333-8333-333333333333",sessionId:"44444444-4444-4444-8444-444444444444",aal:"aal1"};
const tenant="55555555-5555-4555-8555-555555555555",lifecycle="66666666-6666-4666-8666-666666666666";
suite("strategy PostgreSQL isolation and durable history",()=>{
 let admin:pg.Pool,root:pg.Pool,edge:pg.Pool,service:ReturnType<typeof createStrategyService>;
 const database=`strategy_test_${crypto.randomUUID().replaceAll("-","")}`;
 beforeAll(async()=>{
  root=new pg.Pool({connectionString:url});await root.query(`create database ${database}`);
  admin=new pg.Pool({connectionString:url!.replace(/postgres$/u,database)});
  await admin.query(`do $$ begin
   if not exists(select 1 from pg_roles where rolname='argus_edge') then create role argus_edge login noinherit; end if;
   if not exists(select 1 from pg_roles where rolname='argus_identity_owner') then create role argus_identity_owner nologin noinherit; end if;
   if not exists(select 1 from pg_roles where rolname='argus_member') then create role argus_member nologin noinherit; end if;
   if not exists(select 1 from pg_roles where rolname='argus_runtime') then create role argus_runtime nologin; end if;
   if not exists(select 1 from pg_roles where rolname='argus_callback') then create role argus_callback nologin; end if;
   if not exists(select 1 from pg_roles where rolname='argus_public_preview') then create role argus_public_preview nologin; end if;
   if not exists(select 1 from pg_roles where rolname='anon') then create role anon nologin; end if;
   if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
   end $$;
   grant argus_member to argus_edge;
   create schema auth;create schema argus_app;create schema argus_private;create schema extensions;
   create extension pgcrypto with schema extensions;
   create table auth.users(id uuid primary key);
   create table auth.sessions(id uuid primary key,user_id uuid,not_after timestamptz);
   create table argus_app.members(user_id uuid primary key,tenant_id uuid,lifecycle_id uuid,status text);
   create table argus_app.member_lifecycles(id uuid primary key,tenant_id uuid,identity_subject_id uuid,state text);
   grant usage on schema argus_app,argus_private to argus_edge,argus_member,argus_identity_owner;
   grant usage on schema extensions to argus_identity_owner;
   grant select on argus_app.members to argus_identity_owner;
   grant select,update on argus_app.member_lifecycles to argus_identity_owner;
   grant create on schema argus_private to argus_identity_owner;`);
  // Extract the retained production context functions, rather than replacing
  // trusted identity with forgeable test-only JWT/GUC authorization.
  const foundation=await readFile("../supabase/migrations/20260829043359_u3_identity_security_foundation.sql","utf8");
  const serialized=await readFile("../supabase/migrations/20260829102909_u3_serialize_request_context_lifecycle.sql","utf8");
  const locks=await readFile("../supabase/migrations/20260829073116_u5_strengthen_brokerage_relations.sql","utf8");
  for(const [source,name,args] of [[locks,"lock_open_member_lifecycle","uuid,uuid,uuid"],[serialized,"install_request_context","uuid,uuid,text"],[foundation,"read_trusted_request_context",""],[foundation,"trusted_request_user_id",""],[foundation,"trusted_request_tenant_id",""],[foundation,"trusted_request_lifecycle_id",""]]){
   const start=source!.indexOf(`create or replace function argus_private.${name}(`),end=source!.indexOf("$$;",start)+3;
   if(start<0||end<3)throw new Error("retained_identity_function_not_found");
   await admin.query(source!.slice(start,end));await admin.query(`alter function argus_private.${name}(${args}) owner to argus_identity_owner;revoke all on function argus_private.${name}(${args}) from public`);
  }
  await admin.query(`grant execute on function argus_private.install_request_context(uuid,uuid,text) to argus_edge;
   grant execute on function argus_private.read_trusted_request_context(),argus_private.trusted_request_user_id(),argus_private.trusted_request_tenant_id(),argus_private.trusted_request_lifecycle_id() to argus_member;`);
  await admin.query(await readFile("../supabase/migrations/20260908003020_strategy_lab_control_plane.sql","utf8"));
  for(const p of [owner,other]){
   const t=p===owner?tenant:crypto.randomUUID(),l=p===owner?lifecycle:crypto.randomUUID();
   await admin.query("insert into auth.users values ($1);",[p.userId]);
   await admin.query("insert into auth.sessions values ($1,$2,null)",[p.sessionId,p.userId]);
   await admin.query("insert into argus_app.member_lifecycles values ($1,$2,$3,'open')",[l,t,p.userId]);
   await admin.query("insert into argus_app.members values ($1,$2,$3,'active')",[p.userId,t,l]);
  }
  edge=new pg.Pool({connectionString:url!.replace("postgres@","argus_edge@").replace(/postgres$/u,database)});
  service=createStrategyService(createStrategyRepository(edge as unknown as DatabasePool));
 },30000);
 afterAll(async()=>{await edge?.end();await admin?.end();if(root){await root.query(`drop database if exists ${database}`);await root.end();}},15000);
 it("uses the real owner/lifecycle RLS and rejects forged claims without trusted context",async()=>{
  await service.configure(owner,crypto.randomUUID(),{strategyId:"MR-v1",symbol:"AAPL",parameters:{}});
  expect((await service.status(other)).configurations).toHaveLength(0);
  const c=await edge.connect();try{await c.query("begin;set local role argus_member");await c.query("select set_config('request.jwt.claims',$1,true)",[JSON.stringify({sub:owner.userId})]);expect((await c.query("select count(*)::int n from argus_app.strategy_records")).rows[0].n).toBe(0);await expect(c.query("select argus_private.install_request_context($1,$2,'aal1')",[owner.userId,owner.sessionId])).rejects.toMatchObject({code:"42501"});}finally{await c.query("rollback");c.release();}
 });
 it("rejects cross-owner inserts and updates to immutable evidence even under a valid member context",async()=>{
  const c=await edge.connect();try{
   await c.query("begin");await c.query("select argus_private.install_request_context($1,$2,'aal1')",[owner.userId,owner.sessionId]);await c.query("set local role argus_member");
   expect((await c.query("select count(*)::int n from argus_app.strategy_records where kind='device_credential'")).rows[0].n).toBe(0);
   await expect(c.query("insert into argus_app.strategy_records(owner_user_id,tenant_id,lifecycle_id,kind,id,body) values($1,$2,$3,'configuration',$4::uuid,jsonb_build_object('id',$4::uuid::text))",[other.userId,tenant,lifecycle,crypto.randomUUID()])).rejects.toMatchObject({code:"42501"});
   await c.query("rollback;begin");await c.query("select argus_private.install_request_context($1,$2,'aal1')",[owner.userId,owner.sessionId]);await c.query("set local role argus_member");
   await expect(c.query("update argus_app.strategy_records set body=body||'{\"symbol\":\"SPY\"}'::jsonb where kind='configuration'")).rejects.toMatchObject({code:"23000"});
  }finally{await c.query("rollback");c.release();}
 });
 it("consumes pairing once under concurrent redemption and rejects deleted sessions",async()=>{
  const pair=await service.pairing(other,crypto.randomUUID());const results=await Promise.allSettled([1,2].map(()=>service.pair({pairingToken:pair.pairingToken,name:"Local test",platform:"linux"})));
  expect(results.filter(v=>v.status==="fulfilled")).toHaveLength(1);const accepted=results.find(v=>v.status==="fulfilled") as PromiseFulfilledResult<{deviceId:string;deviceToken:string}>;
  expect((await service.devicePrincipal(`${accepted.value.deviceId}.${accepted.value.deviceToken}`)).principal.userId).toBe(other.userId);
  await admin.query("delete from auth.sessions where id=$1",[other.sessionId]);await expect(service.devicePrincipal(`${accepted.value.deviceId}.${accepted.value.deviceToken}`)).rejects.toMatchObject({status:401});await expect(service.status(other)).rejects.toMatchObject({status:401});
 });
 it("retains pause, exact replay lookup, and quiet-account health after more than 24000 archived events",async()=>{
  const key=crypto.randomUUID(),input={strategyId:"MOM-v1" as const,symbol:"SPY",parameters:{}};
  const config=await service.configure(owner,key,input),pair=await service.pairing(owner,crypto.randomUUID()),device=await service.pair({pairingToken:pair.pairingToken,name:"Archive test",platform:"windows"});
  const accounts=[{accountId:"quiet",environment:"SIMULATE" as const,currency:"USD" as const},{accountId:"noisy",environment:"SIMULATE" as const,currency:"USD" as const}];
  await service.poll(owner,device.deviceId,{sequence:1,instanceId:owner.sessionId,accounts,acks:[]});
  const quiet=await service.deploy(owner,crypto.randomUUID(),{strategyVersionId:config.id,configurationHash:config.configurationHash,deviceId:device.deviceId,accountId:"quiet",mode:"paper"});
  const noisy=await service.deploy(owner,crypto.randomUUID(),{strategyVersionId:config.id,configurationHash:config.configurationHash,deviceId:device.deviceId,accountId:"noisy",mode:"paper"});
  const event={schemaVersion:"leo.evidence-event.v1" as const,id:crypto.randomUUID(),deploymentId:quiet.id,kind:"reconciliation" as const,occurredAt:new Date().toISOString(),sequence:1,payload:{consistent:true,positionsFlat:true,workingOrders:0,unknownOrders:0}};
  await service.events(owner,device.deviceId,crypto.randomUUID(),{events:[event]});
  await admin.query(`insert into argus_app.strategy_records(owner_user_id,tenant_id,lifecycle_id,kind,id,body)
   select $1,$2,$3,'evidence',id,jsonb_build_object('id',id,'schemaVersion','leo.evidence-event.v1','deploymentId',$4::text,'kind','heartbeat','occurredAt',clock_timestamp(),'sequence',n,'payload','{}'::jsonb) from (select gen_random_uuid() id,generate_series(1,24001) n) fixture`,[owner.userId,tenant,lifecycle,noisy.id]);
  const status=await service.status(owner);expect(status.evidence.length).toBeLessThan(220);expect(status.evidence.some(e=>e.id===event.id)).toBe(true);
  expect((await service.configure(owner,key,input)).id).toBe(config.id);
  await service.events(owner,device.deviceId,crypto.randomUUID(),{events:[event]});
  await expect(service.events(owner,device.deviceId,crypto.randomUUID(),{events:[{...event,payload:{consistent:false}}]})).rejects.toMatchObject({code:"event_replay_conflict"});
  await expect(service.events(owner,device.deviceId,crypto.randomUUID(),{events:[{...event,id:crypto.randomUUID()}]})).rejects.toMatchObject({code:"event_sequence_conflict"});
  const paused=await service.control(owner,crypto.randomUUID(),quiet.id,{action:"pause",expectedVersion:1,reason:"Archive test"});expect(paused.action).toBe("pause");
  const races=await Promise.allSettled([1,2].map(()=>service.control(owner,crypto.randomUUID(),quiet.id,{action:"pause",expectedVersion:2,reason:"Concurrency test"})));expect(races.filter(r=>r.status==="fulfilled")).toHaveLength(1);
  const updated=await service.revoke(owner,crypto.randomUUID(),device.deviceId,{reason:"Finished test"});expect(updated.revokedAt).not.toBeNull();await expect(service.devicePrincipal(`${device.deviceId}.${device.deviceToken}`)).rejects.toMatchObject({status:401});
 },30000);
});
