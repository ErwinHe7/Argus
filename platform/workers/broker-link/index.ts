// Read-only account linking. The only broker resource is the authorized-account list.
export const CALLBACK = 'https://leo-broker-link.axio7.workers.dev/oauth/moomoo/callback';
export const AUTHORIZE = 'https://webapi.moomoo.com/oauth2/authorize/confirm';
const TOKEN = 'https://webapi.moomoo.com/oauth2/token';
const ACCOUNTS = 'https://webapi.moomoo.com/api/v1.0/accounts/authorized_trd_accs';
const COOKIE = '__Host-leo_moomoo_binding';
const FLOW_MS = 5 * 60_000;
const LOCK_MS = 20_000;
type Json = Record<string, unknown>;
type Account = {label:string; securityFirm:string; accountType:'cash'|'margin'; markets:number[]};
type Link = {owner_id:string; flow_generation:string; link_generation:string|null; state:'disconnected'|'connected'|'reauthorization_required'; token_blob:string|null; accounts_json:string; checked_at:number|null; refresh_lock:string|null; refresh_started_at:number|null};
type Session = {state_hash:string; owner_id:string; flow_generation:string; binding_hash:string; verifier_blob:string; expires_at:number};
type Tokens = {accessToken:string; refreshToken:string; scope:string; expiresAt:number};
type State = Link['state']|'unavailable';
class Failure extends Error {constructor(public code:string, public status=503){super(code);}}
const obj = (v:unknown):Json => v && typeof v==='object' && !Array.isArray(v) ? v as Json : {};
const encoder = new TextEncoder();
const base64 = (bytes:Uint8Array) => btoa(String.fromCharCode(...bytes));
const unbase64 = (value:string) => Uint8Array.from(atob(value), c=>c.charCodeAt(0));
const url64 = (bytes:Uint8Array) => base64(bytes).replace(/=/g,'').replace(/\+/g,'-').replace(/\//g,'_');
const random = () => url64(crypto.getRandomValues(new Uint8Array(32)));
const digest = async(value:string) => url64(new Uint8Array(await crypto.subtle.digest('SHA-256',encoder.encode(value))));
const headers = {'cache-control':'no-store','x-content-type-options':'nosniff','referrer-policy':'no-referrer','content-security-policy':"default-src 'none'; frame-ancestors 'none'"};
const json = (value:unknown,status=200,extra:HeadersInit={}) => Response.json(value,{status,headers:{...headers,...extra}});

function configured(env:Env):boolean {
  try{return env.LEO_ORIGIN==='https://leo.axio7.workers.dev' && !!env.MOOMOO_CLIENT_ID && unbase64(env.BROKER_TOKEN_ENCRYPTION_KEY).length===32;}catch{return false;}
}
async function boundedBody(response:Request|Response,max:number):Promise<string> {
  if(Number(response.headers.get('content-length'))>max)throw new Failure('body_too_large',413);
  const reader=response.body?.getReader();if(!reader)return '';
  const chunks:Uint8Array[]=[];let size=0;
  try{for(;;){const next=await reader.read();if(next.done)break;size+=next.value.length;if(size>max){await reader.cancel();throw new Failure('body_too_large',413);}chunks.push(next.value);}}finally{reader.releaseLock();}
  const result=new Uint8Array(size);let offset=0;for(const chunk of chunks){result.set(chunk,offset);offset+=chunk.length;}
  return new TextDecoder('utf-8',{fatal:true,ignoreBOM:false}).decode(result);
}
async function upstream(url:string,init:RequestInit):Promise<Json> {
  const response=await fetch(url,{...init,redirect:'manual',signal:AbortSignal.timeout(6000)});
  if(response.status===401||response.status===403)throw new Failure('authorization_expired',401);
  if(!response.ok)throw new Failure('upstream_unavailable');
  return obj(JSON.parse(await boundedBody(response,128*1024)));
}
async function owner(token:string,env:Env):Promise<string> {
  if(!/^Bearer [A-Za-z0-9_.-]{40,8000}$/.test(token))throw new Failure('sign_in_required',401);
  let user:Json;
  try{user=await upstream(`${env.SUPABASE_URL}/auth/v1/user`,{headers:{Authorization:token,apikey:env.SUPABASE_PUBLISHABLE_KEY}});}catch(error){throw new Failure(error instanceof Failure&&error.status===401?'sign_in_required':'identity_unavailable',error instanceof Failure&&error.status===401?401:503);}
  if(typeof user.id!=='string'||!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(user.id)||user.role!=='authenticated'||user.is_anonymous===true||!user.email_confirmed_at||!Array.isArray(user.identities)||!user.identities.some(v=>obj(v).provider==='google'))throw new Failure('google_sign_in_required',403);
  return user.id;
}
async function rate(env:Env,ownerId:string,action:string,max:number,period:number):Promise<void> {
  const row=await env.BROKER_LINKS.prepare('INSERT INTO rate_limits(id,window,count) VALUES (?,?,1) ON CONFLICT(id) DO UPDATE SET count=CASE WHEN window=excluded.window THEN count+1 ELSE 1 END,window=excluded.window RETURNING count').bind(`${ownerId}:${action}`,Math.floor(Date.now()/period)).first<{count:number}>();
  if(!row||row.count>max)throw new Failure('try_again_later',429);
}
async function key(env:Env):Promise<CryptoKey> {
  const bytes=unbase64(env.BROKER_TOKEN_ENCRYPTION_KEY);if(bytes.length!==32)throw new Failure('not_configured');
  return crypto.subtle.importKey('raw',bytes,{name:'AES-GCM'},false,['encrypt','decrypt']);
}
async function seal(env:Env,value:unknown,aad:string):Promise<string> {
  const iv=crypto.getRandomValues(new Uint8Array(12));
  const encrypted=await crypto.subtle.encrypt({name:'AES-GCM',iv,additionalData:encoder.encode(aad)},await key(env),encoder.encode(JSON.stringify(value)));
  return `v1.${base64(iv)}.${base64(new Uint8Array(encrypted))}`;
}
async function open(env:Env,blob:string,aad:string):Promise<unknown> {
  const [version,iv,value,...extra]=blob.split('.');if(version!=='v1'||extra.length||!iv||!value)throw new Failure('invalid_token_storage');
  return JSON.parse(new TextDecoder().decode(await crypto.subtle.decrypt({name:'AES-GCM',iv:unbase64(iv),additionalData:encoder.encode(aad)},await key(env),unbase64(value))));
}
const linkAad = (row:Link) => `link:${row.owner_id}:${row.link_generation}`;
const getLink = (env:Env,ownerId:string) => env.BROKER_LINKS.prepare('SELECT * FROM broker_links WHERE owner_id=?').bind(ownerId).first<Link>();

export function readScopes(value:unknown):{canonical:string; accounts:Set<string>} {
  if(typeof value!=='string'||value.length>5000)throw new Failure('readonly_required');
  const scopes=value.trim().split(/\s+/);const accounts=new Set<string>();
  if(scopes.length>52||!scopes.includes('trade:read'))throw new Failure('readonly_required');
  for(const scope of scopes){if(scope==='trade:read'||scope==='quote:read')continue;if(!/^accid:[0-9]{1,24}$/.test(scope))throw new Failure('readonly_required');accounts.add(scope.slice(6));}
  if(!accounts.size)throw new Failure('readonly_required');
  return {canonical:[...new Set(scopes)].sort().join(' '),accounts};
}
function parseTokens(data:Json,previous?:Tokens):Tokens {
  if(data.token_type!=='Bearer'||typeof data.access_token!=='string'||data.access_token.length<16||data.access_token.length>16_000||/\s/.test(data.access_token)||!Number.isSafeInteger(data.expires_in)||Number(data.expires_in)<61||Number(data.expires_in)>31_536_000)throw new Failure('invalid_token_response');
  const scope=readScopes(data.scope).canonical;
  // The documented public-client refresh does not rotate its refresh token.
  if(previous&&(scope!==previous.scope||(data.refresh_token!==undefined&&data.refresh_token!==previous.refreshToken)))throw new Failure('refresh_grant_changed');
  const refresh=previous?.refreshToken??data.refresh_token;
  if(typeof refresh!=='string'||refresh.length<16||refresh.length>16_000||/\s/.test(refresh))throw new Failure('invalid_token_response');
  return {accessToken:data.access_token,refreshToken:refresh,scope,expiresAt:Date.now()+Number(data.expires_in)*1000};
}
async function tokenRequest(env:Env,fields:Record<string,string>):Promise<Json> {
  return upstream(TOKEN,{method:'POST',headers:{'content-type':'application/x-www-form-urlencoded'},body:new URLSearchParams({...fields,client_id:env.MOOMOO_CLIENT_ID})});
}
async function accountList(tokens:Tokens):Promise<Account[]> {
  const authorized=readScopes(tokens.scope).accounts;
  const data=await upstream(ACCOUNTS,{headers:{Authorization:`Bearer ${tokens.accessToken}`}});
  const accounts=obj(data.d).accounts;
  if(data.s!=='ok'||!Array.isArray(accounts)||accounts.length>50)throw new Failure('invalid_account_response');
  const seen=new Set<string>();
  return accounts.map(item=>{
    const a=obj(item);
    if(typeof a.account_id!=='string'||!authorized.has(a.account_id)||seen.has(a.account_id)||!['FUTUSECURITIES','FUTUSG','FUTUINC','FUTUCA'].includes(String(a.security_firm))||!['cash','margin'].includes(String(a.acc_type))||!Array.isArray(a.enable_market)||!a.enable_market.every(v=>Number.isSafeInteger(v)&&Number(v)>0&&Number(v)<100)||typeof a.account_card_number!=='string'||!/^[0-9]{4,24}$/.test(a.account_card_number))throw new Failure('invalid_account_response');
    seen.add(a.account_id);
    return {label:`••••${a.account_card_number.slice(-4)}`,securityFirm:a.security_firm as string,accountType:a.acc_type as Account['accountType'],markets:a.enable_market as number[]};
  });
}
function view(env:Env,row:Link|null,state:State=row?.state??'disconnected',message?:string) {
  return {schemaVersion:'broker-link/v1',provider:'moomoo',configured:configured(env),state,checkedAt:row?.checked_at?new Date(row.checked_at).toISOString():null,accounts:row?JSON.parse(row.accounts_json):[],readonly:true,executionEnabled:false,message:message??({disconnected:'No broker account is linked.',connected:'Account permissions were checked with moomoo. Read-only access; trading is not enabled.',reauthorization_required:'Reconnect at moomoo to restore verified read-only access.',unavailable:'Account verification is unavailable. Previously checked accounts are shown.'}[state])};
}
async function invalidate(env:Env,row:Link,lock?:string):Promise<void> {
  // An older access token's failed GET must not invalidate a refresh which
  // completed while that request was in flight. Match the exact encrypted revision.
  const sql="UPDATE broker_links SET state='reauthorization_required',token_blob=NULL,refresh_lock=NULL,refresh_started_at=NULL WHERE owner_id=? AND link_generation=? AND token_blob IS ?"+(lock?' AND refresh_lock=?':'');
  const values=[row.owner_id,row.link_generation,row.token_blob,...(lock?[lock]:[])];await env.BROKER_LINKS.prepare(sql).bind(...values).run();
}
async function access(env:Env,row:Link):Promise<Tokens> {
  let tokens:Tokens;
  try{tokens=await open(env,row.token_blob!,linkAad(row)) as Tokens;readScopes(tokens.scope);if(!Number.isSafeInteger(tokens.expiresAt)||typeof tokens.accessToken!=='string'||typeof tokens.refreshToken!=='string')throw new Error();}catch{await invalidate(env,row);throw new Failure('reauthorization_required');}
  if(row.refresh_lock){
    if(!row.refresh_started_at||Date.now()-row.refresh_started_at>=LOCK_MS)await invalidate(env,row,row.refresh_lock);
    throw new Failure('refresh_pending');
  }
  if(tokens.expiresAt>Date.now()+60_000)return tokens;
  const lock=random();
  const acquired=await env.BROKER_LINKS.prepare("UPDATE broker_links SET refresh_lock=?,refresh_started_at=? WHERE owner_id=? AND link_generation=? AND state='connected' AND refresh_lock IS NULL RETURNING owner_id").bind(lock,Date.now(),row.owner_id,row.link_generation).first();
  if(!acquired)throw new Failure('refresh_pending');
  try{
    const refreshed=parseTokens(await tokenRequest(env,{grant_type:'refresh_token',refresh_token:tokens.refreshToken}),tokens);
    const blob=await seal(env,refreshed,linkAad(row));
    const saved=await env.BROKER_LINKS.prepare("UPDATE broker_links SET token_blob=?,refresh_lock=NULL,refresh_started_at=NULL WHERE owner_id=? AND link_generation=? AND refresh_lock=? AND state='connected' RETURNING owner_id").bind(blob,row.owner_id,row.link_generation,lock).first();
    if(!saved)throw new Failure('link_changed');row.token_blob=blob;return refreshed;
  }catch(error){await invalidate(env,row,lock);throw error;}
}
async function status(env:Env,ownerId:string):Promise<Response> {
  let row=await getLink(env,ownerId);
  if(!configured(env))return json(view(env,row,'unavailable','Broker linking is not configured.'));
  if(!row||row.state!=='connected')return json(view(env,row));
  try{
    if(!row.token_blob||!row.link_generation){await invalidate(env,row);throw new Failure('reauthorization_required');}
    const tokens=await access(env,row);const accounts=await accountList(tokens);
    // A disconnect or a newer callback wins over an in-flight status request.
    const updated=await env.BROKER_LINKS.prepare("UPDATE broker_links SET accounts_json=?,checked_at=? WHERE owner_id=? AND link_generation=? AND state='connected' RETURNING *").bind(JSON.stringify(accounts),Date.now(),ownerId,row.link_generation).first<Link>();
    return json(view(env,updated??await getLink(env,ownerId)));
  }catch(error){
    if(error instanceof Failure&&error.status===401)await invalidate(env,row);
    const current=await getLink(env,ownerId);
    if(!current||current.state!=='connected')return json(view(env,current));
    return json(view(env,current,'unavailable'),503);
  }
}
function bindingCookie(request:Request):string {
  const matches=(request.headers.get('cookie')??'').split(';').map(v=>v.trim()).filter(v=>v.startsWith(`${COOKIE}=`));
  if(matches.length!==1)return '';const value=matches[0].slice(COOKIE.length+1);return /^[A-Za-z0-9_-]{43}$/.test(value)?value:'';
}
function redirect(env:Env,result:string):Response {
  return new Response(null,{status:303,headers:{...headers,location:`${env.LEO_ORIGIN}/#/brokers?moomoo=${result}`,'set-cookie':`${COOKIE}=; Path=/; Secure; HttpOnly; SameSite=Lax; Max-Age=0`}});
}
async function start(request:Request,env:Env):Promise<Response> {
  if(!configured(env))throw new Failure('not_configured');
  if(request.headers.get('content-type')?.split(';')[0]!=='application/x-www-form-urlencoded')throw new Failure('form_required',415);
  const form=new URLSearchParams(await boundedBody(request,9000));
  if([...form.keys()].some(k=>k!=='access_token')||form.getAll('access_token').length!==1)throw new Failure('invalid_form',400);
  const ownerId=await owner(`Bearer ${form.get('access_token')??''}`,env);
  await rate(env,ownerId,'start',6,60*60_000);
  const state=random(),binding=random(),verifier=random(),generation=random();const stateHash=await digest(state);
  const verifierBlob=await seal(env,verifier,`oauth:${ownerId}:${stateHash}`);
  await env.BROKER_LINKS.prepare("INSERT INTO broker_links(owner_id,flow_generation,state) VALUES (?,?,'disconnected') ON CONFLICT(owner_id) DO UPDATE SET flow_generation=excluded.flow_generation").bind(ownerId,generation).run();
  // Retain no expired codes/verifiers. New flows also invalidate the owner's old sessions.
  await env.BROKER_LINKS.prepare('DELETE FROM oauth_sessions WHERE owner_id=? OR expires_at<?').bind(ownerId,Date.now()).run();
  await env.BROKER_LINKS.prepare('INSERT INTO oauth_sessions(state_hash,owner_id,flow_generation,binding_hash,verifier_blob,created_at,expires_at) VALUES (?,?,?,?,?,?,?)').bind(stateHash,ownerId,generation,await digest(binding),verifierBlob,Date.now(),Date.now()+FLOW_MS).run();
  const url=new URL(AUTHORIZE);url.search=new URLSearchParams({client_id:env.MOOMOO_CLIENT_ID,code_challenge:await digest(verifier),code_challenge_method:'S256',redirect_uri:CALLBACK,response_type:'code',state}).toString();
  return new Response(null,{status:303,headers:{...headers,location:url.href,'set-cookie':`${COOKIE}=${binding}; Path=/; Secure; HttpOnly; SameSite=Lax; Max-Age=300`}});
}
async function callback(request:Request,env:Env):Promise<Response> {
  const query=new URL(request.url).searchParams;const state=query.get('state')??'',binding=bindingCookie(request);
  if(!configured(env)||!binding||!/^[A-Za-z0-9_-]{43}$/.test(state)||query.getAll('state').length!==1||query.getAll('code').length>1||query.getAll('error').length>1)return redirect(env,'failed');
  const row=await env.BROKER_LINKS.prepare('UPDATE oauth_sessions SET used_at=? WHERE state_hash=? AND binding_hash=? AND used_at IS NULL AND expires_at>? RETURNING *').bind(Date.now(),await digest(state),await digest(binding),Date.now()).first<Session>();
  if(!row)return redirect(env,'failed');
  try{
    if(query.has('error'))return redirect(env,'denied');
    const code=query.get('code')??'';if(!code||code.length>4096||/[\s\x00-\x1f]/.test(code))return redirect(env,'failed');
    const current=await getLink(env,row.owner_id);if(current?.flow_generation!==row.flow_generation)return redirect(env,'failed');
    const verifier=await open(env,row.verifier_blob,`oauth:${row.owner_id}:${row.state_hash}`);if(typeof verifier!=='string')throw new Failure('invalid_state');
    const tokens=parseTokens(await tokenRequest(env,{grant_type:'authorization_code',code,redirect_uri:CALLBACK,code_verifier:verifier}));
    const accounts=await accountList(tokens);
    const blob=await seal(env,tokens,`link:${row.owner_id}:${row.flow_generation}`);
    const saved=await env.BROKER_LINKS.prepare("UPDATE broker_links SET link_generation=?,state='connected',token_blob=?,accounts_json=?,checked_at=?,refresh_lock=NULL,refresh_started_at=NULL WHERE owner_id=? AND flow_generation=? RETURNING owner_id").bind(row.flow_generation,blob,JSON.stringify(accounts),Date.now(),row.owner_id,row.flow_generation).first();
    return redirect(env,saved?'linked':'failed');
  }catch(error){return redirect(env,error instanceof Failure&&error.code==='readonly_required'?'readonly_required':'failed');}
  finally{await env.BROKER_LINKS.prepare('DELETE FROM oauth_sessions WHERE state_hash=?').bind(row.state_hash).run();}
}
async function disconnect(request:Request,env:Env,ownerId:string):Promise<Response> {
  const body=await boundedBody(request,1024);if(body.trim()&&body.trim()!=='{}')throw new Failure('server_controls_account',400);
  await rate(env,ownerId,'disconnect',12,60*60_000);
  await env.BROKER_LINKS.prepare("UPDATE broker_links SET flow_generation=?,link_generation=NULL,state='disconnected',token_blob=NULL,accounts_json='[]',checked_at=NULL,refresh_lock=NULL,refresh_started_at=NULL WHERE owner_id=?").bind(random(),ownerId).run();
  await env.BROKER_LINKS.prepare('DELETE FROM oauth_sessions WHERE owner_id=?').bind(ownerId).run();
  return json(view(env,null,'disconnected','Leo deleted its stored access. This does not revoke the authorization at moomoo; review connected apps there.'));
}
export default {
  async fetch(request:Request,env:Env):Promise<Response> {
    const url=new URL(request.url),path=url.pathname;let cors:Record<string,string>={};
    try{
      if(path==='/oauth/moomoo/callback'&&request.method==='GET')return await callback(request,env);
      if(request.headers.get('origin')===env.LEO_ORIGIN)cors={'access-control-allow-origin':env.LEO_ORIGIN,vary:'Origin','access-control-allow-headers':'Authorization, Content-Type','access-control-allow-methods':'GET, POST, OPTIONS'};
      if(path==='/health'&&request.method==='GET')return json({service:'leo-broker-link',schemaVersion:'broker-link/v1',configured:configured(env),readOnly:true,executionEnabled:false},200,cors);
      if(!['/status','/disconnect','/oauth/moomoo/start'].includes(path))throw new Failure('not_found',404);
      if(request.headers.get('origin')!==env.LEO_ORIGIN)throw new Failure('origin_not_allowed',403);
      if(request.method==='OPTIONS')return new Response(null,{status:204,headers:{...headers,...cors}});
      if(url.search)throw new Failure('query_not_allowed',400);
      if((path==='/status'&&request.method!=='GET')||(path!=='/status'&&request.method!=='POST'))throw new Failure('method_not_allowed',405);
      if(path==='/oauth/moomoo/start')return await start(request,env);
      const ownerId=await owner(request.headers.get('authorization')??'',env);
      let response:Response;
      if(path==='/status'){await rate(env,ownerId,'status',30,60_000);response=await status(env,ownerId);}else response=await disconnect(request,env,ownerId);
      Object.entries(cors).forEach(([name,value])=>response.headers.set(name,value));return response;
    }catch(error){return json({error:error instanceof Failure?error.code:'broker_link_unavailable'},error instanceof Failure?error.status:503,cors);}
  }
} satisfies ExportedHandler<Env>;
