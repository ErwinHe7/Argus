import {test} from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {readFileSync} from 'node:fs';
import {createHmac} from 'node:crypto';
import worker,{ACCOUNT,PRODUCT,PLAN,verifyWebhook,checkoutUrl} from './index';
const a='10000000-0000-4000-8000-000000000001',b='20000000-0000-4000-8000-000000000002';
const origin='https://leo.axio7.workers.dev',secret='ws_test_only_not_a_real_key';
function fixture(){
  const db=new DatabaseSync(':memory:');db.exec(readFileSync(new URL('./migrations/0001_billing.sql',import.meta.url),'utf8'));
  function statement(sql:string,args:unknown[]=[]):unknown{return {bind:(...values:unknown[])=>statement(sql,values),first:async()=>db.prepare(sql).get(...args as never[] )??null,all:async()=>({results:db.prepare(sql).all(...args as never[])}),run:async()=>db.prepare(sql).run(...args as never[])};}
  const env={BILLING:{prepare:statement},LEO_ORIGIN:origin,SUPABASE_URL:'https://auth.example',SUPABASE_PUBLISHABLE_KEY:'test_public',WHOP_API_KEY:'test_server_only',WHOP_WEBHOOK_SECRET:secret};
  let identity=a,anon=false,badGoogle=false,outage=false,created=0;
  const memberships:Record<string,Record<string,unknown>>={};const payments:Record<string,unknown[]>={};
  const oldFetch=globalThis.fetch;
  globalThis.fetch=async(input,init)=>{
    const url=new URL(String(input));
    if(url.hostname==='auth.example')return Response.json({id:identity,role:'authenticated',is_anonymous:anon,email_confirmed_at:'2026-01-01',identities:[{provider:badGoogle?'email':'google'}]});
    assert.equal(url.hostname,'api.whop.com');assert.equal(new Headers(init?.headers).get('Api-Version-Date'),url.pathname.endsWith('/payments')?'2026-09-02':'2026-09-11');
    if(outage)return new Response(null,{status:503});
    if(url.pathname.endsWith('/plans/'+PLAN))return Response.json({id:PLAN,product:{id:PRODUCT},currency:'usd',plan_type:'renewal',billing_period:30,renewal_price:99.99,initial_price:0,trial_period_days:null});
    if(url.pathname.endsWith('/checkout_configurations')){created++;const data=JSON.parse(String(init?.body));assert.equal(data.plan_id,PLAN);assert.deepEqual(Object.keys(data.metadata),['leo_checkout_reference']);return Response.json({id:'ch_test'+created,account_id:ACCOUNT,plan:{id:PLAN},metadata:data.metadata,purchase_url:'https://whop.com/checkout/ch_test'+created+'/'});}
    if(url.pathname.includes('/memberships/')){const data=memberships[url.pathname.split('/').pop()!];return data?Response.json(data):new Response(null,{status:404});}
    if(url.pathname.endsWith('/payments'))return Response.json({data:payments[url.searchParams.get('checkout_configuration_ids[]')!]??[],page_info:{has_next_page:false}});
    throw new Error('Unexpected vendor path '+url.pathname);
  };
  const call=(path:string,body?:string,headers:Record<string,string>={})=>worker.fetch(new Request('https://billing.example'+path,{method:body===undefined?'GET':'POST',headers:{origin,authorization:'Bearer '+('test.'.repeat(10)),...headers},body}),env as never);
  const seed=async(id='mem_test12345')=>{
    await call('/checkout','{}');const ref=db.prepare('SELECT reference FROM checkouts WHERE owner_id=?').get(identity)!.reference as string;
    memberships[id]={id,account:{id:ACCOUNT},plan_id:PLAN,product_id:PRODUCT,status:'active',current_period_end:new Date(Date.now()+86400000).toISOString(),cancel_at_period_end:false,metadata:{leo_checkout_reference:ref}};
    return {ref,id};
  };
  const send=async(id:string,mid:string,kind='membership.activated')=>{
    const raw=JSON.stringify({id,type:kind,account_id:ACCOUNT,data:{id:mid}});const timestamp=String(Math.floor(Date.now()/1000));
    return worker.fetch(new Request('https://billing.example/webhook',{method:'POST',body:raw,headers:{'webhook-id':id,'webhook-timestamp':timestamp,'webhook-signature':'v1,'+createHmac('sha256',secret).update(`${id}.${timestamp}.${raw}`).digest('base64')}}),env as never);
  };
  return {db,call,seed,send,memberships,payments,setIdentity:(v:string)=>identity=v,setAnon:()=>anon=true,setBadGoogle:()=>badGoogle=true,setOutage:()=>outage=true,getCreated:()=>created,close:()=>{globalThis.fetch=oldFetch;db.close();}};
}
test('raw HMAC, timestamp, body changes, rotation signatures',async()=>{
  const raw='{"test":true}',id='msg_testing123',timestamp=String(Math.floor(Date.now()/1000));
  const h=new Headers({'webhook-id':id,'webhook-timestamp':timestamp,'webhook-signature':'v1,'+createHmac('sha256',secret).update(`${id}.${timestamp}.${raw}`).digest('base64')});
  assert.equal(await verifyWebhook(raw,h,secret),true);assert.equal(await verifyWebhook(raw+' ',h,secret),false);assert.equal(await verifyWebhook(raw,h,secret,Date.now()+301000),false);assert.equal(await verifyWebhook(raw,h,'wrong'),false);
  h.set('webhook-signature','v1,invalid '+h.get('webhook-signature'));assert.equal(await verifyWebhook(raw,h,secret),true);
});
test('origin, anonymous, missing token, forged owner and non-Google identity rejected',async()=>{
  const f=fixture();try{assert.equal((await f.call('/status',undefined,{origin:'https://evil.example'})).status,403);assert.equal((await f.call('/status',undefined,{authorization:''})).status,401);assert.equal((await f.call('/checkout',JSON.stringify({owner_id:b,plan_id:'wrong'}))).status,400);f.setAnon();assert.equal((await f.call('/status')).status,403);}finally{f.close();}
  const g=fixture();try{g.setBadGoogle();assert.equal((await g.call('/status')).status,403);}finally{g.close();}
});
test('server-owned checkout reused; redirect alone creates no membership',async()=>{
  const f=fixture();try{const r=await f.call('/checkout','{}');assert.equal(r.status,200);assert.equal((await r.json()).url,'https://whop.com/checkout/ch_test1/');await f.call('/checkout','{}');assert.equal(f.getCreated(),1);assert.equal((await (await f.call('/status')).json()).status,'none');assert.equal((await f.call('/checkout','{"success":true}')).status,400);}finally{f.close();}
});
test('verified membership is owner scoped; duplicate and delayed events read current state',async()=>{
  const f=fixture();try{const {id}=await f.seed();assert.equal((await f.send('msg_event123',id)).status,200);assert.equal((await (await f.call('/status')).json()).status,'active');assert.equal((await f.call('/checkout','{}')).status,409);
    assert.equal((await (await f.send('msg_event123',id)).json()).duplicate,true);assert.equal(f.db.prepare('SELECT count(*) n FROM memberships').get()!.n,1);
    f.setIdentity(b);assert.equal((await (await f.call('/status')).json()).status,'none');f.setIdentity(a);f.memberships[id].status='expired';await f.send('msg_eventOlder123',id);assert.equal((await (await f.call('/status')).json()).status,'inactive');
  }finally{f.close();}
});
test('missed webhook recovery from owner checkout payments; outages never assert paid',async()=>{
  const f=fixture();try{const {id}=await f.seed();f.payments.ch_test1=[{membership_id:id}];assert.equal((await (await f.call('/status')).json()).status,'active');f.setOutage();const r=await f.call('/status');assert.equal(r.status,503);assert.equal((await r.json()).status,'unavailable');}finally{f.close();}
});
test('wrong product and invented reference cannot grant membership',async()=>{
  const f=fixture();try{const {id}=await f.seed();f.memberships[id].product_id='prod_wrong';assert.equal((await f.send('msg_badProduct',id)).status,503);assert.equal((await (await f.call('/status')).json()).status,'none');f.memberships[id].product_id=PRODUCT;f.memberships[id].metadata={leo_checkout_reference:'f'.repeat(64)};await f.send('msg_badReference',id);assert.equal(f.db.prepare('SELECT count(*) n FROM memberships').get()!.n,0);}finally{f.close();}
});
test('existing membership cannot be transferred to another owner by metadata mutation',async()=>{
  const f=fixture();try{const {id}=await f.seed();await f.send('msg_original123',id);f.setIdentity(b);const other=await f.seed('mem_other12345');f.memberships[id].metadata={leo_checkout_reference:other.ref};await f.send('msg_rebind123',id);assert.equal(f.db.prepare('SELECT owner_id FROM memberships WHERE id=?').get(id)!.owner_id,a);assert.equal((await (await f.call('/status')).json()).status,'none');}finally{f.close();}
});
test('cancel at period end stays active until expiry, missing expiry fails closed',async()=>{
  const f=fixture();try{const {id}=await f.seed();f.memberships[id].cancel_at_period_end=true;await f.send('msg_cancel123',id);assert.equal((await (await f.call('/status')).json()).status,'active');f.memberships[id].current_period_end=new Date(Date.now()-1000).toISOString();assert.equal((await (await f.call('/status')).json()).status,'inactive');f.memberships[id].current_period_end=null;assert.equal((await (await f.call('/status')).json()).status,'inactive');}finally{f.close();}
});
test('checkout destination rejects credential, host and path substitution',()=>{
  for(const u of ['http://whop.com/checkout/ch_ok','https://whop.com.evil/checkout/ch_ok','https://evil@whop.com/checkout/ch_ok','https://whop.com/home/'])assert.throws(()=>checkoutUrl(u));
});
test('older checkout recovery is complete or unavailable; never silently limited to three',async()=>{
  const f=fixture();try{const {id}=await f.seed();f.payments.ch_test1=[{membership_id:id}];
    for(let n=2;n<=5;n++)f.db.prepare('INSERT INTO checkouts(reference,owner_id,created_at,whop_id,url) VALUES (?,?,?,?,?)').run(String(n).padStart(64,'0'),a,Date.now()+n,'ch_old'+n,'https://whop.com/checkout/ch_old'+n+'/');
    assert.equal((await (await f.call('/status')).json()).status,'active');
    for(let n=6;n<=21;n++)f.db.prepare('INSERT INTO checkouts(reference,owner_id,created_at,whop_id) VALUES (?,?,?,?)').run(String(n).padStart(64,'0'),a,Date.now()+n,'ch_old'+n);
    assert.equal((await (await f.call('/status')).json()).status,'unavailable');
    assert.equal((await f.call('/checkout','{}')).status,503);
  }finally{f.close();}
});
test('unresolved owner payment blocks checkout and relevant webhook remains retryable',async()=>{
  const f=fixture();try{const {id}=await f.seed();f.payments.ch_test1=[{membership_id:'mem_missing123'}];
    assert.equal((await (await f.call('/status')).json()).status,'unavailable');assert.equal((await f.call('/checkout','{}')).status,503);
    f.memberships[id].product_id='prod_wrong';assert.equal((await f.send('msg_retry12345',id)).status,503);assert.equal(f.db.prepare('SELECT count(*) n FROM events').get()!.n,0);
    f.memberships[id].product_id=PRODUCT;assert.equal((await f.send('msg_retry12345',id)).status,200);
  }finally{f.close();}
});
test('known membership 404 is retryable using the same webhook event',async()=>{
  const f=fixture();try{const {id}=await f.seed();await f.send('msg_initial123',id);const saved=f.memberships[id];delete f.memberships[id];
    assert.equal((await f.send('msg_transient123',id)).status,503);assert.equal(f.db.prepare('SELECT id FROM events WHERE id=?').get('msg_transient123'),undefined);
    f.memberships[id]=saved;assert.equal((await f.send('msg_transient123',id)).status,200);assert.equal((await (await f.call('/status')).json()).status,'active');
  }finally{f.close();}
});
