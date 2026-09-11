import {test} from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {readFileSync} from 'node:fs';
import worker,{CALLBACK,AUTHORIZE,readScopes} from './index';

const a='10000000-0000-4000-8000-000000000001',b='20000000-0000-4000-8000-000000000002';
const origin='https://leo.axio7.workers.dev',bearer='test.'.repeat(12),accountId='1234567890123456';
const readonly=`quote:read trade:read accid:${accountId}`;
function deferred(){let release!:()=>void;const promise=new Promise<void>(resolve=>release=resolve);return {promise,release};}
function fixture(){
  const db=new DatabaseSync(':memory:');db.exec(readFileSync(new URL('./migrations/0001_broker_link.sql',import.meta.url),'utf8'));
  function statement(sql:string,args:unknown[]=[]):unknown{return {bind:(...values:unknown[])=>statement(sql,values),first:async()=>db.prepare(sql).get(...args as never[])??null,all:async()=>({results:db.prepare(sql).all(...args as never[])}),run:async()=>db.prepare(sql).run(...args as never[])};}
  const env={BROKER_LINKS:{prepare:statement},LEO_ORIGIN:origin,SUPABASE_URL:'https://auth.example',SUPABASE_PUBLISHABLE_KEY:'test_public',MOOMOO_CLIENT_ID:'test_public_client',BROKER_TOKEN_ENCRYPTION_KEY:Buffer.alloc(32,7).toString('base64')};
  let identity=a,anonymous=false,google=true,authStatus=200,clock=Date.now(),scope=readonly,tokenCalls=0,refreshCalls=0,accountCalls=0,accountStatus=200,tokenStatus=200,expires=7200,tokenThrows=false;
  let refreshOverride:Record<string,unknown>={},accountOverride:unknown=null;
  let tokenGate:ReturnType<typeof deferred>|null=null,accountGate:ReturnType<typeof deferred>|null=null;
  const oldFetch=globalThis.fetch,oldNow=Date.now;Date.now=()=>clock;
  globalThis.fetch=async(input,init)=>{
    const url=new URL(String(input));assert.equal(init?.redirect,'manual');assert.ok(init?.signal);
    if(url.hostname==='auth.example')return Response.json({id:identity,role:'authenticated',is_anonymous:anonymous,email_confirmed_at:'2026-01-01',identities:[{provider:google?'google':'email'}]},{status:authStatus});
    assert.equal(url.origin,'https://webapi.moomoo.com');
    if(url.pathname==='/oauth2/token'){
      tokenCalls++;assert.equal(init?.method,'POST');const form=new URLSearchParams(String(init?.body));assert.equal(form.get('client_id'),'test_public_client');
      const refresh=form.get('grant_type')==='refresh_token';
      if(refresh){refreshCalls++;assert.equal(form.get('refresh_token'),'original_refresh_token_test_only');}else{assert.equal(form.get('redirect_uri'),CALLBACK);assert.match(form.get('code_verifier')!,/^[A-Za-z0-9_-]{43}$/);}
      await tokenGate?.promise;
      if(tokenThrows)throw new Error('Simulated network timeout');
      if(tokenStatus!==200)return new Response(null,{status:tokenStatus});
      return Response.json({access_token:'broker_access_token_test_only',token_type:'Bearer',expires_in:expires,scope,...(refresh?refreshOverride:{refresh_token:'original_refresh_token_test_only'})});
    }
    if(url.pathname==='/api/v1.0/accounts/authorized_trd_accs'){
      accountCalls++;assert.equal(init?.method,undefined);assert.equal(url.search,'');assert.equal(new Headers(init?.headers).get('authorization'),'Bearer broker_access_token_test_only');
      await accountGate?.promise;
      if(accountStatus!==200)return new Response(null,{status:accountStatus});
      return Response.json(accountOverride??{s:'ok',d:{accounts:[{account_id:accountId,security_firm:'FUTUINC',enable_market:[2],acc_type:'cash',account_card_number:'87654321',univs_account_card_number:accountId}]}});
    }
    throw new Error('Unexpected broker route '+url.pathname);
  };
  const call=(path:string,body?:string,extra:Record<string,string>={})=>worker.fetch(new Request('https://leo-broker-link.axio7.workers.dev'+path,{method:body===undefined?'GET':'POST',headers:{origin,authorization:`Bearer ${bearer}`,...extra},body}),env as never);
  const begin=async()=>{
    const response=await call('/oauth/moomoo/start',new URLSearchParams({access_token:bearer}).toString(),{'content-type':'application/x-www-form-urlencoded'});
    assert.equal(response.status,303);const location=response.headers.get('location')!;const cookie=response.headers.get('set-cookie')!.split(';')[0];
    const url=new URL(location);assert.equal(url.origin+url.pathname,AUTHORIZE);assert.equal(url.searchParams.get('code_challenge_method'),'S256');assert.equal(url.searchParams.get('redirect_uri'),CALLBACK);assert.equal(url.searchParams.has('scope'),false);
    assert.match(response.headers.get('set-cookie')!,/Path=\/; Secure; HttpOnly; SameSite=Lax/);
    return {state:url.searchParams.get('state')!,cookie,location};
  };
  const finish=(flow:{state:string;cookie:string},query='code=test_authorization_code')=>worker.fetch(new Request(`${CALLBACK}?state=${flow.state}&${query}`,{headers:{cookie:flow.cookie}}),env as never);
  const connect=async()=>{const flow=await begin();const response=await finish(flow);assert.match(response.headers.get('location')!,/moomoo=linked$/);return flow;};
  return {db,env,call,begin,finish,connect,advance:(ms:number)=>clock+=ms,setIdentity:(id:string)=>identity=id,setAnon:()=>anonymous=true,setGoogle:(v:boolean)=>google=v,setAuthStatus:(v:number)=>authStatus=v,setScope:(v:string)=>scope=v,setAccountStatus:(v:number)=>accountStatus=v,setTokenStatus:(v:number)=>tokenStatus=v,setExpires:(v:number)=>expires=v,setTokenThrows:()=>tokenThrows=true,setRefresh:(v:Record<string,unknown>)=>refreshOverride=v,setAccounts:(v:unknown)=>accountOverride=v,setTokenGate:(v:ReturnType<typeof deferred>|null)=>tokenGate=v,setAccountGate:(v:ReturnType<typeof deferred>|null)=>accountGate=v,counts:()=>({tokenCalls,refreshCalls,accountCalls}),close:()=>{globalThis.fetch=oldFetch;Date.now=oldNow;db.close();}};
}
async function eventually(check:()=>boolean){for(let n=0;n<100;n++){if(check())return;await new Promise(resolve=>setTimeout(resolve,1));}throw new Error('Expected async stage not reached');}

test('only Google server identities and exact origin authorize state; no arbitrary account or order route',async()=>{
  const f=fixture();try{
    assert.equal((await f.call('/status',undefined,{origin:'https://evil.example'})).status,403);
    assert.equal((await f.call('/status',undefined,{authorization:''})).status,401);
    assert.equal((await f.call('/status?owner_id='+b)).status,400);
    assert.equal((await f.call('/disconnect','{"account_id":"123"}')).status,400);
    assert.equal((await f.call('/orders','{}')).status,404);
    f.setAnon();assert.equal((await f.call('/status')).status,403);
  }finally{f.close();}
  const g=fixture();try{g.setGoogle(false);assert.equal((await g.call('/status')).status,403);g.setGoogle(true);g.setAuthStatus(401);assert.equal((await g.call('/status')).status,401);}finally{g.close();}
});
test('public readiness never asserts a link; unconfigured status is explicit',async()=>{
  const f=fixture();try{const health=await(await f.call('/health')).json();assert.equal(health.configured,true);assert.equal(health.executionEnabled,false);assert.equal((await(await f.call('/status')).json()).state,'disconnected');f.env.BROKER_TOKEN_ENCRYPTION_KEY='';const status=await(await f.call('/status')).json();assert.equal(status.configured,false);assert.equal(status.state,'unavailable');assert.equal((await f.call('/oauth/moomoo/start','access_token='+bearer,{'content-type':'application/x-www-form-urlencoded'})).status,503);}finally{f.close();}
});
test('state, verifier and tokens stay private; real account response is masked and owner scoped',async()=>{
  const f=fixture();try{
    const flow=await f.begin();const session=f.db.prepare('SELECT * FROM oauth_sessions').get()!;
    assert.notEqual(session.state_hash,flow.state);assert.notEqual(session.binding_hash,flow.cookie.split('=')[1]);assert.match(String(session.verifier_blob),/^v1\./);
    await f.finish(flow);const stored=f.db.prepare('SELECT * FROM broker_links').get()!;assert.match(String(stored.token_blob),/^v1\./);assert.equal(JSON.stringify(stored).includes('broker_access_token'),false);assert.equal(JSON.stringify(stored).includes(accountId),false);assert.equal(f.db.prepare('SELECT count(*) n FROM oauth_sessions').get()!.n,0);
    const result=await(await f.call('/status')).json();assert.equal(result.state,'connected');assert.equal(result.readonly,true);assert.equal(result.executionEnabled,false);assert.deepEqual(result.accounts,[{label:'••••4321',securityFirm:'FUTUINC',accountType:'cash',markets:[2]}]);assert.ok(result.checkedAt);assert.equal(JSON.stringify(result).includes(accountId),false);
    f.setIdentity(b);assert.equal((await(await f.call('/status')).json()).state,'disconnected');await f.call('/disconnect','{}');f.setIdentity(a);assert.equal((await(await f.call('/status')).json()).state,'connected');
  }finally{f.close();}
});
test('missing or wrong browser binding cannot consume valid state; callbacks are single use',async()=>{
  const f=fixture();try{const flow=await f.begin();for(const cookie of ['',flow.cookie.replace(/=.+$/,'='+'x'.repeat(43))]){assert.match((await f.finish({...flow,cookie})).headers.get('location')!,/moomoo=failed$/);assert.equal(f.counts().tokenCalls,0);}
    assert.match((await f.finish(flow)).headers.get('location')!,/moomoo=linked$/);assert.match((await f.finish(flow)).headers.get('location')!,/moomoo=failed$/);assert.equal(f.counts().tokenCalls,1);
  }finally{f.close();}
});
test('expired, duplicate-query and denied consent never exchange tokens',async()=>{
  const f=fixture();try{const flow=await f.begin();assert.match((await f.finish(flow,'code=one&code=two')).headers.get('location')!,/failed$/);f.advance(300_001);assert.match((await f.finish(flow)).headers.get('location')!,/failed$/);const second=await f.begin();assert.match((await f.finish(second,'error=access_denied')).headers.get('location')!,/denied$/);assert.match((await f.finish(second)).headers.get('location')!,/failed$/);assert.equal(f.counts().tokenCalls,0);}finally{f.close();}
});
test('write, wildcard, missing account and unknown scopes are rejected before resource calls',async()=>{
  for(const scopes of ['trade:read accid:*',readonly+' trade:write',readonly+' quote:write','trade:read','quote:read accid:123',readonly+' profile:read'])assert.throws(()=>readScopes(scopes));
  const f=fixture();try{f.setScope(readonly+' trade:write');const flow=await f.begin();assert.match((await f.finish(flow)).headers.get('location')!,/readonly_required$/);assert.equal(f.counts().accountCalls,0);assert.equal((await(await f.call('/status')).json()).state,'disconnected');}finally{f.close();}
});
test('unscoped or malformed account data cannot establish a connection',async()=>{
  const f=fixture();try{f.setAccounts({s:'ok',d:{accounts:[{account_id:'999',security_firm:'FUTUINC',enable_market:[2],acc_type:'cash',account_card_number:'1234'}]}});const flow=await f.begin();assert.match((await f.finish(flow)).headers.get('location')!,/failed$/);assert.equal((await(await f.call('/status')).json()).state,'disconnected');}finally{f.close();}
});
test('broker outage retains checked values without claiming connected; 401 removes authorization',async()=>{
  const f=fixture();try{await f.connect();const before=await(await f.call('/status')).json();f.advance(10_000);f.setAccountStatus(503);const response=await f.call('/status');assert.equal(response.status,503);const stale=await response.json();assert.equal(stale.state,'unavailable');assert.deepEqual(stale.accounts,before.accounts);assert.equal(stale.checkedAt,before.checkedAt);f.setAccountStatus(401);const expired=await(await f.call('/status')).json();assert.equal(expired.state,'reauthorization_required');assert.deepEqual(expired.accounts,before.accounts);assert.equal(f.db.prepare('SELECT token_blob FROM broker_links').get()!.token_blob,null);}finally{f.close();}
});
test('documented nonrotating refresh keeps original token when response omits it',async()=>{
  const f=fixture();try{f.setExpires(61);await f.connect();f.advance(2000);const result=await(await f.call('/status')).json();assert.equal(result.state,'connected');assert.equal(f.counts().refreshCalls,1);f.advance(2000);assert.equal((await(await f.call('/status')).json()).state,'connected');assert.equal(f.counts().refreshCalls,2);}finally{f.close();}
});
test('unexpected rotation, scope drift and ambiguous refresh fail closed without a second refresh',async()=>{
  for(const mode of ['rotation','scope','timeout']){const f=fixture();try{f.setExpires(61);await f.connect();f.advance(2000);if(mode==='rotation')f.setRefresh({refresh_token:'unexpected_rotated_token'});if(mode==='scope')f.setScope('trade:read accid:'+accountId);if(mode==='timeout')f.setTokenThrows();assert.equal((await(await f.call('/status')).json()).state,'reauthorization_required');await f.call('/status');assert.equal(f.counts().refreshCalls,1);assert.equal(f.db.prepare('SELECT token_blob FROM broker_links').get()!.token_blob,null);}finally{f.close();}}
});
test('competing refreshes share a durable lock; stale interrupted refresh requires new consent',async()=>{
  const f=fixture();try{f.setExpires(61);await f.connect();f.advance(2000);const gate=deferred();f.setTokenGate(gate);const pending=f.call('/status');await eventually(()=>f.counts().refreshCalls===1);const second=await(await f.call('/status')).json();assert.equal(second.state,'unavailable');assert.equal(f.counts().refreshCalls,1);gate.release();assert.equal((await(await pending).json()).state,'connected');
    f.db.prepare('UPDATE broker_links SET refresh_lock=?,refresh_started_at=?').run('interrupted',Date.now()-21_000);assert.equal((await(await f.call('/status')).json()).state,'reauthorization_required');assert.equal(f.counts().refreshCalls,1);
  }finally{f.close();}
});
test('disconnect during authorization exchange cannot resurrect the link',async()=>{
  const f=fixture();try{const flow=await f.begin(),gate=deferred();f.setTokenGate(gate);const pending=f.finish(flow);await eventually(()=>f.counts().tokenCalls===1);const disconnected=await(await f.call('/disconnect','{}')).json();assert.equal(disconnected.state,'disconnected');assert.match(disconnected.message,/does not revoke/);gate.release();assert.match((await pending).headers.get('location')!,/failed$/);assert.equal((await(await f.call('/status')).json()).state,'disconnected');assert.equal(f.db.prepare('SELECT token_blob FROM broker_links').get()!.token_blob,null);}finally{f.close();}
});
test('disconnect during account verification cannot resurrect the link',async()=>{
  const f=fixture();try{await f.connect();const gate=deferred();f.setAccountGate(gate);const pending=f.call('/status');await eventually(()=>f.counts().accountCalls===2);await f.call('/disconnect','{}');gate.release();assert.equal((await(await pending).json()).state,'disconnected');assert.equal(f.db.prepare('SELECT token_blob FROM broker_links').get()!.token_blob,null);}finally{f.close();}
});
test('disconnect during refresh cannot save the returned token',async()=>{
  const f=fixture();try{f.setExpires(61);await f.connect();f.advance(2000);const gate=deferred();f.setTokenGate(gate);const pending=f.call('/status');await eventually(()=>f.counts().refreshCalls===1);await f.call('/disconnect','{}');gate.release();assert.equal((await(await pending).json()).state,'disconnected');assert.equal(f.db.prepare('SELECT token_blob FROM broker_links').get()!.token_blob,null);}finally{f.close();}
});
test('an old access-token 401 cannot invalidate a concurrent successful refresh',async()=>{
  const f=fixture();try{f.setExpires(61);await f.connect();const gate=deferred();f.setAccountGate(gate);const oldRequest=f.call('/status');await eventually(()=>f.counts().accountCalls===2);f.advance(2000);f.setAccountGate(null);assert.equal((await(await f.call('/status')).json()).state,'connected');assert.equal(f.counts().refreshCalls,1);f.setAccountStatus(401);gate.release();assert.equal((await(await oldRequest).json()).state,'unavailable');assert.equal(f.db.prepare('SELECT state FROM broker_links').get()!.state,'connected');f.setAccountStatus(200);assert.equal((await(await f.call('/status')).json()).state,'connected');assert.equal(f.counts().refreshCalls,1);}finally{f.close();}
});
test('old callback cannot overwrite a newer flow and its completed link',async()=>{
  const f=fixture();try{const first=await f.begin(),gate=deferred();f.setTokenGate(gate);const pending=f.finish(first);await eventually(()=>f.counts().tokenCalls===1);f.setTokenGate(null);const second=await f.begin();assert.match((await f.finish(second)).headers.get('location')!,/linked$/);const generation=f.db.prepare('SELECT link_generation FROM broker_links').get()!.link_generation;gate.release();assert.match((await pending).headers.get('location')!,/failed$/);assert.equal(f.db.prepare('SELECT link_generation FROM broker_links').get()!.link_generation,generation);}finally{f.close();}
});
test('encrypted token blobs cannot be substituted across owners',async()=>{
  const f=fixture();try{await f.connect();f.setIdentity(b);await f.connect();const row=f.db.prepare('SELECT token_blob FROM broker_links WHERE owner_id=?').get(a)!;f.db.prepare('UPDATE broker_links SET token_blob=? WHERE owner_id=?').run(row.token_blob,b);assert.equal((await(await f.call('/status')).json()).state,'reauthorization_required');f.setIdentity(a);assert.equal((await(await f.call('/status')).json()).state,'connected');}finally{f.close();}
});
test('failed token exchange consumes the flow and never retries the authorization code',async()=>{
  const f=fixture();try{f.setTokenStatus(503);const flow=await f.begin();assert.match((await f.finish(flow)).headers.get('location')!,/failed$/);f.setTokenStatus(200);assert.match((await f.finish(flow)).headers.get('location')!,/failed$/);assert.equal(f.counts().tokenCalls,1);}finally{f.close();}
});
