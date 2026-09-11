import { Hono } from "hono";
import { z } from "zod";
import {configurationInputSchema,controlInputSchema,deploymentInputSchema,devicePairInputSchema,devicePollInputSchema,eventsInputSchema,explanationInputSchema,pairingInputSchema,researchInputSchema,researchReportInputSchema,retireInputSchema,revokeInputSchema} from "./contracts.ts";
import {createStrategyService,sha256} from "./service.ts";
import {StrategyError,type Principal,type StrategyRepository,type SupervisorProvider} from "./ports.ts";
import type { RateLimitPort } from "../../ports/infrastructure.ts";
type Env={Variables:{principal:Principal;deviceId:string;requestId:string}};
export function exactStrategyOrigins(value:string){const origins=value.split(",").map(v=>v.trim());if(!origins.length||new Set(origins).size!==origins.length||origins.some(v=>{try{const u=new URL(v);return u.protocol!=="https:"||u.origin!==v||u.username!==""||u.password!=="";}catch{return true;}}))throw new Error("invalid_strategy_origins");return Object.freeze(origins);}
async function body(request:Request){if(!/^application\/json(?:;.*)?$/i.test(request.headers.get("content-type")??""))throw new StrategyError(415,"json_required","Send a JSON request.");const reader=request.body?.getReader();if(!reader)return {};const chunks:Uint8Array[]=[];let length=0;try{for(;;){const{done,value}=await reader.read();if(done)break;length+=value.length;if(length>65536){await reader.cancel();throw new StrategyError(413,"body_too_large","The request is too large.");}chunks.push(value);}}finally{reader.releaseLock();}const bytes=new Uint8Array(length);let offset=0;for(const chunk of chunks){bytes.set(chunk,offset);offset+=chunk.length;}try{return JSON.parse(new TextDecoder().decode(bytes));}catch{throw new StrategyError(422,"invalid_json","The JSON request is invalid.");}}
function validated<T>(schema:z.ZodType<T>,value:unknown):T{const parsed=schema.safeParse(value);if(!parsed.success)throw new StrategyError(422,"validation_failed","The request does not match the current strategy contract.");return parsed.data;}
const uuidSchema=z.string().uuid();
export function createStrategyApp(options:{repository:StrategyRepository;verifyAccessToken:(token:string)=>Promise<Principal>;origins:readonly string[];rateLimit:RateLimitPort;supervisor?:SupervisorProvider|undefined;now?:(()=>Date)|undefined}){
 const app=new Hono<Env>();const service=createStrategyService(options.repository,{now:options.now,supervisor:options.supervisor});
 app.use("*",async(c,next)=>{c.set("requestId",crypto.randomUUID());c.header("cache-control","private, no-store");c.header("x-content-type-options","nosniff");c.header("referrer-policy","no-referrer");c.header("x-request-id",c.get("requestId"));const origin=c.req.header("origin");if(origin&&!options.origins.includes(origin))throw new StrategyError(403,"origin_denied","This website origin is not allowed.");if(origin){c.header("access-control-allow-origin",origin);c.header("vary","origin");c.header("access-control-allow-methods","GET, POST, OPTIONS");c.header("access-control-allow-headers","authorization, apikey, content-type, idempotency-key, if-match, x-request-id");c.header("access-control-expose-headers","x-request-id, retry-after");}if(c.req.method==="OPTIONS")return c.body(null,204);await next();});
 app.use("/v1/*",async(c,next)=>{
  const path=c.req.path;let scope="public";
  if(path!=="/v1/catalog"&&path!=="/v1/device/pair"){
   const token=/^Bearer ([A-Za-z0-9._~-]{1,16391})$/.exec(c.req.header("authorization")??"")?.[1];if(!token)throw new StrategyError(401,"unauthorized","Sign in or pair a connector to continue.");
   if(path.startsWith("/v1/device/")){const device=await service.devicePrincipal(token);c.set("principal",device.principal);c.set("deviceId",device.deviceId);scope=`device:${device.deviceId}`;}
   else{try{c.set("principal",await options.verifyAccessToken(token));}catch{throw new StrategyError(401,"unauthorized","A valid member session is required.");}scope=c.get("principal").userId;}
  }
  const outcome=await options.rateLimit.allow(await sha256(`strategy:${scope}:${path.replace(/[a-f0-9-]{36}/g,"{id}")}`),{limit:scope==="public"?30:180,windowSeconds:60});if(!outcome.allowed)throw new StrategyError(429,"rate_limited","Too many requests. Wait before retrying.");await next();
 });
 const result=(c:any,data:unknown)=>c.json({data,meta:{requestId:c.get("requestId")}});
 const key=(c:any)=>validated(uuidSchema,c.req.header("idempotency-key"));
 app.get("/v1/catalog",c=>result(c,service.catalog()));
 app.get("/v1/status",async c=>result(c,await service.status(c.get("principal"))));
 app.post("/v1/configurations",async c=>result(c,await service.configure(c.get("principal"),key(c),validated(configurationInputSchema,await body(c.req.raw)))));
 app.post("/v1/pairing",async c=>{validated(pairingInputSchema,await body(c.req.raw));return result(c,await service.pairing(c.get("principal"),key(c)));});
 app.post("/v1/deployments",async c=>result(c,await service.deploy(c.get("principal"),key(c),validated(deploymentInputSchema,await body(c.req.raw)))));
 app.post("/v1/deployments/:id/controls",async c=>result(c,await service.control(c.get("principal"),key(c),validated(uuidSchema,c.req.param("id")),validated(controlInputSchema,await body(c.req.raw)))));
 app.post("/v1/deployments/:id/retire",async c=>result(c,await service.retire(c.get("principal"),key(c),validated(uuidSchema,c.req.param("id")),validated(retireInputSchema,await body(c.req.raw)))));
 app.post("/v1/devices/:id/revoke",async c=>result(c,await service.revoke(c.get("principal"),key(c),validated(uuidSchema,c.req.param("id")),validated(revokeInputSchema,await body(c.req.raw)))));
 app.post("/v1/research-runs",async c=>result(c,await service.research(c.get("principal"),key(c),validated(researchInputSchema,await body(c.req.raw)))));
 app.post("/v1/research-runs/:id/report",async c=>result(c,await service.uploadReport(c.get("principal"),key(c),validated(uuidSchema,c.req.param("id")),validated(researchReportInputSchema,await body(c.req.raw)))));
 app.post("/v1/explanations",async c=>result(c,await service.explanation(c.get("principal"),validated(explanationInputSchema,await body(c.req.raw)),key(c))));
 app.post("/v1/device/pair",async c=>result(c,await service.pair(validated(devicePairInputSchema,await body(c.req.raw)))));
 app.post("/v1/device/poll",async c=>result(c,await service.poll(c.get("principal"),c.get("deviceId"),validated(devicePollInputSchema,await body(c.req.raw)))));
 app.post("/v1/device/events",async c=>result(c,await service.events(c.get("principal"),c.get("deviceId"),key(c),validated(eventsInputSchema,await body(c.req.raw)))));
 app.post("/v1/device/research-runs/:id/report",async c=>result(c,await service.uploadReport(c.get("principal"),key(c),validated(uuidSchema,c.req.param("id")),validated(researchReportInputSchema,await body(c.req.raw)),c.get("deviceId"))));
 app.notFound(c=>c.json({error:{code:"not_found",message:"This strategy endpoint does not exist.",requestId:c.get("requestId")}},404));
 app.onError((error,c)=>{const known=error instanceof StrategyError;return c.json({error:{code:known?error.code:"service_unavailable",message:known?error.publicMessage:"The strategy service is unavailable.",requestId:c.get("requestId"),retryable:!known}},(known?error.status:503) as 400);});
 return app;
}
