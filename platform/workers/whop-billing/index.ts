// Isolated Whop membership records. No Paddle writes and no trading authority.
export const PLAN = 'plan_lx8Xc92y4i1Mg';
export const PRODUCT = 'prod_CxrnkRxYwMyY4';
export const ACCOUNT = 'biz_ZtGv6nIHwM9GUh';
const API_VERSION = '2026-09-11';
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const memberId = /^mem_[A-Za-z0-9]{5,80}$/;
type Json = Record<string, unknown>;
type Checkout = {reference:string; owner_id:string; created_at:number; whop_id:string|null; url:string|null};
type Membership = {id:string; owner_id:string; reference:string; status:string; checked_at:number; period_end:string|null; cancel_at_period_end:number};
type Status = {provider:'whop';status:'active'|'inactive'|'none'|'unavailable';checkedAt:string|null;cancelAtPeriodEnd:boolean;renewalPeriodEnd:string|null};
class Failure extends Error {constructor(public code:string, public status=503){super(code);}}
const obj = (v:unknown):Json => v && typeof v==='object' && !Array.isArray(v) ? v as Json : {};
const idOf = (v:unknown):unknown => typeof v==='string' ? v : obj(v).id;
const json = (value:unknown,status=200,headers:HeadersInit={}) => Response.json(value,{status,headers:{'cache-control':'no-store','x-content-type-options':'nosniff',...headers}});

async function boundedBody(request:Request, max:number):Promise<string> {
  if (Number(request.headers.get('content-length'))>max) throw new Failure('request_too_large',413);
  const reader=request.body?.getReader(); if(!reader)return '';
  const parts:Uint8Array[]=[];let size=0;
  try {for(;;){const chunk=await reader.read();if(chunk.done)break;size+=chunk.value.length;if(size>max){await reader.cancel();throw new Failure('request_too_large',413);}parts.push(chunk.value);}}
  finally{reader.releaseLock();}
  const all=new Uint8Array(size);let offset=0;for(const part of parts){all.set(part,offset);offset+=part.length;}return new TextDecoder('utf-8',{fatal:true,ignoreBOM:false}).decode(all);
}

async function whop(env:Env,path:string,body?:Json):Promise<Json|null>{
  if(!env.WHOP_API_KEY)throw new Failure('billing_not_configured');
  const response=await fetch(`https://api.whop.com/api/v1${path}`,{method:body?'POST':'GET',headers:{Authorization:`Bearer ${env.WHOP_API_KEY}`,'Api-Version-Date':path.startsWith('/payments?')?'2026-09-02':API_VERSION,'content-type':'application/json'},body:body?JSON.stringify(body):undefined,redirect:'manual',signal:AbortSignal.timeout(4000)});
  if(response.status===404)return null;
  if(!response.ok)throw new Failure('whop_unavailable');
  return obj(await response.json());
}

async function owner(request:Request,env:Env):Promise<string>{
  const token=request.headers.get('authorization')??'';
  if(!/^Bearer [A-Za-z0-9_.-]{40,8000}$/.test(token))throw new Failure('sign_in_required',401);
  // Supabase verifies the token on the server; browser user objects never authorize billing.
  const response=await fetch(`${env.SUPABASE_URL}/auth/v1/user`,{headers:{Authorization:token,apikey:env.SUPABASE_PUBLISHABLE_KEY},redirect:'manual',signal:AbortSignal.timeout(4000)});
  if(response.status===400||response.status===401||response.status===403)throw new Failure('sign_in_required',401);
  if(!response.ok)throw new Failure('identity_unavailable');
  const user=obj(await response.json());
  if(typeof user.id!=='string'||!uuid.test(user.id)||user.role!=='authenticated'||user.is_anonymous===true||!user.email_confirmed_at||!Array.isArray(user.identities)||!user.identities.some(v=>obj(v).provider==='google'))throw new Failure('google_sign_in_required',403);
  return user.id;
}

async function rate(env:Env,ownerId:string,action:string,max:number,period:number){
  const window=Math.floor(Date.now()/period);
  const row=await env.BILLING.prepare('INSERT INTO rate_limits(id,window,count) VALUES (?,?,1) ON CONFLICT(id) DO UPDATE SET count=CASE WHEN window=excluded.window THEN count+1 ELSE 1 END,window=excluded.window RETURNING count').bind(`${ownerId}:${action}`,window).first<{count:number}>();
  if(!row||row.count>max)throw new Failure('try_again_later',429);
}

function empty(status:Status['status']='none'):Status{return {provider:'whop',status,checkedAt:new Date().toISOString(),cancelAtPeriodEnd:false,renewalPeriodEnd:null};}
export function membershipFacts(data:Json):{status:string;period:string|null;cancel:boolean}|null{
  // Dated membership response verified against Whop's actual 2026-09-11 API.
  if(idOf(data.account)!==ACCOUNT||data.plan_id!==PLAN||data.product_id!==PRODUCT||typeof data.status!=='string'||typeof data.cancel_at_period_end!=='boolean')return null;
  const end=data.current_period_end;
  if(end!==null&&(typeof end!=='string'||!Number.isFinite(Date.parse(end))))return null;
  return {status:data.status,period:typeof end==='string'?end:null,cancel:data.cancel_at_period_end};
}

async function syncMembership(env:Env,id:string,expectedOwner?:string):Promise<Membership|null>{
  if(!memberId.test(id))return null;
  const data=await whop(env,`/memberships/${id}`);
  if(!data){await env.BILLING.prepare("UPDATE memberships SET status='unavailable',checked_at=? WHERE id=?").bind(Date.now(),id).run();return null;}
  if(data.id!==id)return null;
  const facts=membershipFacts(data);
  const reference=obj(data.metadata).leo_checkout_reference;
  if(typeof reference!=='string'||!/^[a-f0-9]{64}$/.test(reference))return null;
  const checkout=await env.BILLING.prepare('SELECT * FROM checkouts WHERE reference=?').bind(reference).first<Checkout>();
  if(!checkout||(expectedOwner&&checkout.owner_id!==expectedOwner))return null;
  if(!checkout.whop_id||!facts)throw new Failure('membership_verification_unavailable');
  // The 256-bit server-created reference maps to one immutable owner. Neither
  // webhook fields nor browser input select an owner. A membership can never move owners.
  await env.BILLING.prepare('INSERT INTO memberships(id,owner_id,reference,status,checked_at,period_end,cancel_at_period_end) VALUES (?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET status=excluded.status,checked_at=excluded.checked_at,period_end=excluded.period_end,cancel_at_period_end=excluded.cancel_at_period_end WHERE memberships.owner_id=excluded.owner_id AND memberships.reference=excluded.reference')
    .bind(id,checkout.owner_id,reference,facts.status,Date.now(),facts.period,Number(facts.cancel)).run();
  return env.BILLING.prepare('SELECT * FROM memberships WHERE id=? AND owner_id=? AND reference=?').bind(id,checkout.owner_id,reference).first<Membership>();
}

async function statusFor(env:Env,ownerId:string):Promise<Status>{
  // Recover a missed webhook through payments bound to this owner's checkout.
  const recent=await env.BILLING.prepare('SELECT * FROM checkouts WHERE owner_id=? AND whop_id IS NOT NULL ORDER BY created_at DESC LIMIT 21').bind(ownerId).all<Checkout>();
  if(recent.results.length>20)throw new Failure('payment_history_review_required');
  for(const checkout of recent.results){
    const payments=await whop(env,`/payments?account_id=${ACCOUNT}&checkout_configuration_ids[]=${encodeURIComponent(checkout.whop_id!)}&first=100`);
    if(!payments||!Array.isArray(payments.data)||obj(payments.page_info).has_next_page!==false||payments.data.length>100)throw new Failure('payment_history_review_required');
    for(const item of payments.data){
      const payment=obj(item);const id=idOf(payment.membership_id??payment.membership);
      if(typeof id==='string'){if(!await syncMembership(env,id,ownerId))throw new Failure('membership_verification_unavailable');}
      else if(!['failed','canceled','cancelled'].includes(String(payment.status)))throw new Failure('payment_verification_pending');
    }
  }
  const rows=await env.BILLING.prepare('SELECT * FROM memberships WHERE owner_id=? LIMIT 20').bind(ownerId).all<Membership>();
  if(rows.results.length>=20)throw new Failure('membership_review_required');
  let result=empty(rows.results.length?'inactive':'none');
  for(const row of rows.results){
    const current=await syncMembership(env,row.id,ownerId);
    if(!current)throw new Failure('membership_verification_unavailable');
    const active=current.status==='active'&&current.period_end!==null&&Date.parse(current.period_end)>Date.now();
    if(active||result.status!=='active') result={provider:'whop',status:active?'active':'inactive',checkedAt:new Date(current.checked_at).toISOString(),cancelAtPeriodEnd:!!current.cancel_at_period_end,renewalPeriodEnd:current.period_end};
  }
  return result;
}

export function checkoutUrl(value:unknown):string{
  if(typeof value!=='string')throw new Failure('invalid_checkout');
  const url=new URL(value);
  if(url.origin!=='https://whop.com'||url.username||url.password||!/^\/checkout\/(?:ch|plan)_[A-Za-z0-9]+\/?$/.test(url.pathname))throw new Failure('invalid_checkout');
  return url.href;
}

async function checkoutFor(env:Env,ownerId:string):Promise<string>{
  if((await statusFor(env,ownerId)).status==='active')throw new Failure('membership_already_active',409);
  const previous=await env.BILLING.prepare('SELECT * FROM checkouts WHERE owner_id=? AND created_at>? AND url IS NOT NULL ORDER BY created_at DESC LIMIT 1').bind(ownerId,Date.now()-30*60*1000).first<Checkout>();
  if(previous?.url)return checkoutUrl(previous.url);
  const plan=await whop(env,`/plans/${PLAN}`);
  if(!plan||plan.id!==PLAN||idOf(plan.product)!==PRODUCT||plan.currency!=='usd'||plan.plan_type!=='renewal'||plan.billing_period!==30||plan.renewal_price!==99.99||plan.initial_price!==0||(plan.trial_period_days!==null&&plan.trial_period_days!==0))throw new Failure('plan_changed_review_required');
  const reference=Array.from(crypto.getRandomValues(new Uint8Array(32)),v=>v.toString(16).padStart(2,'0')).join('');
  await env.BILLING.prepare('INSERT INTO checkouts(reference,owner_id,created_at) VALUES (?,?,?)').bind(reference,ownerId,Date.now()).run();
  const configuration=await whop(env,'/checkout_configurations',{plan_id:PLAN,metadata:{leo_checkout_reference:reference},redirect_url:`${env.LEO_ORIGIN}/#/membership`});
  if(!configuration||typeof configuration.id!=='string'||!/^ch_[A-Za-z0-9]+$/.test(configuration.id)||configuration.account_id!==ACCOUNT||idOf(configuration.plan)!==PLAN||obj(configuration.metadata).leo_checkout_reference!==reference)throw new Failure('checkout_verification_failed');
  const url=checkoutUrl(configuration.purchase_url);
  await env.BILLING.prepare('UPDATE checkouts SET whop_id=?,url=? WHERE reference=? AND owner_id=?').bind(configuration.id,url,reference,ownerId).run();
  return url;
}

export async function verifyWebhook(raw:string,headers:Headers,secret:string,now=Date.now()):Promise<boolean>{
  const id=headers.get('webhook-id')??'',timestamp=headers.get('webhook-timestamp')??'',signatures=headers.get('webhook-signature')??'';
  if(!secret||!/^msg_[A-Za-z0-9_-]{5,100}$/.test(id)||!/^\d{10}$/.test(timestamp)||Math.abs(now/1000-Number(timestamp))>300||signatures.length>2048)return false;
  const key=await crypto.subtle.importKey('raw',new TextEncoder().encode(secret),{name:'HMAC',hash:'SHA-256'},false,['verify']);
  const message=new TextEncoder().encode(`${id}.${timestamp}.${raw}`);
  for(const candidate of signatures.split(' ')){
    const [version,signature]=candidate.split(',');if(version!=='v1'||!signature)continue;
    try{const bytes=Uint8Array.from(atob(signature),c=>c.charCodeAt(0));if(bytes.length===32&&await crypto.subtle.verify('HMAC',key,bytes,message))return true;}catch{/* Invalid signature is not an exception to verification. */}
  }
  return false;
}

async function webhook(request:Request,env:Env):Promise<Response>{
  const raw=await boundedBody(request,128*1024);
  if(!await verifyWebhook(raw,request.headers,env.WHOP_WEBHOOK_SECRET))throw new Failure('invalid_signature',401);
  let event:Json;try{event=obj(JSON.parse(raw));}catch{throw new Failure('invalid_event',400);}
  const id=request.headers.get('webhook-id')!;
  if(event.id!==id||(event.account_id??event.company_id)!==ACCOUNT||typeof event.type!=='string')return json({accepted:true,ignored:true});
  if(await env.BILLING.prepare('SELECT id FROM events WHERE id=?').bind(id).first())return json({accepted:true,duplicate:true});
  const data=obj(event.data);let membership:unknown;
  if(event.type.startsWith('membership.'))membership=data.id;
  else if(event.type.startsWith('payment.'))membership=idOf(data.membership_id??data.membership);
  else if(event.type.startsWith('refund.')||event.type.startsWith('dispute.')){
    const payment=idOf(data.payment_id??data.payment);
    if(typeof payment==='string'&&/^pay_[A-Za-z0-9]+$/.test(payment)){const current=await whop(env,`/payments/${payment}`);membership=idOf(current?.membership_id??current?.membership);}
  }
  if(typeof membership==='string'){
    const synced=await syncMembership(env,membership);
    if(!synced){
      const known=await env.BILLING.prepare('SELECT id FROM memberships WHERE id=?').bind(membership).first();
      const reference=obj(data.metadata).leo_checkout_reference;
      const pending=typeof reference==='string'&&await env.BILLING.prepare('SELECT reference FROM checkouts WHERE reference=?').bind(reference).first();
      if(known||pending)throw new Failure('membership_verification_unavailable');
    }
  }
  // No client success state or webhook lifecycle label grants access. /status
  // always reads the current Whop membership, also resolving out-of-order events.
  await env.BILLING.prepare('INSERT OR IGNORE INTO events(id,kind,received_at) VALUES (?,?,?)').bind(id,event.type,Date.now()).run();
  return json({accepted:true});
}

export default {
  async fetch(request:Request,env:Env):Promise<Response>{
    const path=new URL(request.url).pathname;let headers:Record<string,string>={};
    try{
      if(path==='/health'&&request.method==='GET')return json({service:'leo-whop-billing',schemaVersion:'whop-billing/v1',configured:!!env.WHOP_API_KEY&&!!env.WHOP_WEBHOOK_SECRET,liveTradingEnabled:false});
      if(path==='/webhook'&&request.method==='POST')return await webhook(request,env);
      if(!['/status','/checkout'].includes(path))throw new Failure('not_found',404);
      if(request.headers.get('origin')!==env.LEO_ORIGIN)throw new Failure('origin_not_allowed',403);
      headers={'access-control-allow-origin':env.LEO_ORIGIN,'vary':'Origin','access-control-allow-headers':'Authorization, Content-Type','access-control-allow-methods':'GET, POST, OPTIONS'};
      if(request.method==='OPTIONS')return new Response(null,{status:204,headers});
      if((path==='/status'&&request.method!=='GET')||(path==='/checkout'&&request.method!=='POST'))throw new Failure('method_not_allowed',405);
      const ownerId=await owner(request,env);
      if(path==='/status'){
        await rate(env,ownerId,'status',30,60*1000);
        try{return json(await statusFor(env,ownerId),200,headers);}catch{return json({...empty('unavailable'),checkedAt:null},503,headers);}
      }
      const body=await boundedBody(request,1024);
      if(body.trim()&&body.trim()!=='{}')throw new Failure('server_controls_checkout',400);
      await rate(env,ownerId,'checkout',3,60*60*1000);
      return json({url:await checkoutFor(env,ownerId)},200,headers);
    }catch(error){return json({error:error instanceof Failure?error.code:'billing_unavailable'},error instanceof Failure?error.status:503,headers);}
  }
} satisfies ExportedHandler<Env>;
