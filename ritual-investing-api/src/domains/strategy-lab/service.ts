import { configurationInputSchema, pauseRequestSchema, researchReportInputSchema, RESEARCH_RISK_DEFAULTS, STRATEGY_CATALOG, type ConfigurationInput, type DeploymentMandate, type DevicePollInput, type EvidenceEvent, type Explanation, type ResearchReport, type ResearchRun, type StrategyControl, type StrategyStatus } from "./contracts.ts";
import { StrategyError, type Idempotency, type Principal, type StrategyRepository, type SupervisorProvider, type Workspace } from "./ports.ts";
function fail(status:number,code:string,message:string):never {throw new StrategyError(status,code,message);}
const LEASE_MS=15000;
export async function sha256(value:string){return Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256",new TextEncoder().encode(value)))).map(v=>v.toString(16).padStart(2,"0")).join("");}
export function randomToken(){return Array.from(crypto.getRandomValues(new Uint8Array(32))).map(v=>v.toString(16).padStart(2,"0")).join("");}
function canonical(value:unknown):string {if(Array.isArray(value))return `[${value.map(canonical).join(",")}]`;if(value!==null&&typeof value==="object")return `{${Object.entries(value as Record<string,unknown>).sort(([a],[b])=>a.localeCompare(b)).map(([k,v])=>`${JSON.stringify(k)}:${canonical(v)}`).join(",")}}`;return JSON.stringify(value);}
export function configurationIdentity(input:ConfigurationInput){return JSON.stringify({schemaVersion:"leo.strategy-version.v1",strategyId:input.strategyId,symbol:input.symbol,parameters:{}});}
function secretFree(value:unknown):boolean {if(Array.isArray(value))return value.every(secretFree);if(value&&typeof value==="object")return Object.entries(value).every(([key,item])=>!/password|secret|token|credential|authorization|api.?key/i.test(key)&&secretFree(item));return true;}
function assertCapacity(state:Workspace,key:"configurations"|"devices"|"deployments"|"researchRuns",max:number){if(state[key].length>=max)fail(409,"workspace_capacity","This workspace has reached its current capacity.");}
function control(state:Workspace,d:DeploymentMandate,action:"pause"|"resume",reason:string,now:string){
 d.state=action==="pause"?"paused":"running";d.mandateVersion++;d.leaseGeneration++;d.leaseExpiresAt=null;d.pauseReason=action==="pause"?reason:null;d.updatedAt=now;
 const c:StrategyControl={id:crypto.randomUUID(),deploymentId:d.id,action,reason,mandateVersion:d.mandateVersion,configurationHash:d.configurationHash,createdAt:now,status:"pending",acknowledgedAt:null};state.controls.push(c);return c;
}
function expire(state:Workspace,now:string){for(const d of state.deployments){const device=state.devices.find(v=>v.id===d.deviceId);if(d.state==="running"&&(!device?.lastSeenAt||Date.parse(now)-Date.parse(device.lastSeenAt)>LEASE_MS||device.revokedAt)){control(state,d,"pause","Connector lease expired; explicit resume required.",now);}}}
export function createStrategyService(repository:StrategyRepository,options:{now?:(()=>Date)|undefined;supervisor?:SupervisorProvider|undefined}={}){
 const now=()=> (options.now?.()??new Date()).toISOString();
 const mutate=<T>(principal:Principal,key:string,path:string,body:unknown,fn:(state:Workspace,time:string)=>Promise<T>,replayable=true)=>repository.transact(principal,async state=>{
  const requestHash=await sha256(canonical({path,body}));const prior=state.idempotency.find(v=>v.id===key)??await state.lookupRecord?.("idempotency",key) as Idempotency|undefined;
  if(prior){if(prior.requestHash!==requestHash)fail(409,"idempotency_conflict","That request key was used for different content.");if(!prior.replayable)fail(409,"one_time_response","This one-time credential was already issued. Create a new pairing request.");return prior.response as T;}
  expire(state,now());const result=await fn(state,now());state.idempotency.push({id:key,requestHash,response:replayable?result:null,replayable,createdAt:now()});return result;
 });
 return {
  catalog:()=>({strategies:STRATEGY_CATALOG,riskDefaults:RESEARCH_RISK_DEFAULTS,modes:["dry_run","paper"],liveExecution:false}),
  status:(principal:Principal)=>repository.transact(principal,async state=>{expire(state,now());return {membership:{userId:principal.userId,status:"active" as const},configurations:state.configurations,deployments:state.deployments,devices:state.devices,researchRuns:state.researchRuns,evidence:state.evidence,controls:state.controls} satisfies StrategyStatus;}),
  configure:(principal:Principal,key:string,input:ConfigurationInput)=>mutate(principal,key,"configurations",input,async(state,time)=>{
   assertCapacity(state,"configurations",100);const body=configurationInputSchema.parse(input);const configurationHash=await sha256(configurationIdentity(body));
   const value={...body,schemaVersion:"leo.strategy-version.v1" as const,id:crypto.randomUUID(),symbols:[body.symbol],configurationHash,createdAt:time};state.configurations.push(value);return value;
  }),
  pairing:(principal:Principal,key:string)=>mutate(principal,key,"pairing",{},async(state,time)=>{
   assertCapacity(state,"devices",20);const pairingToken=randomToken();const expiresAt=new Date(Date.parse(time)+300000).toISOString();state.pairings.push({id:crypto.randomUUID(),tokenHash:await sha256(pairingToken),expiresAt,consumedAt:null,sessionId:principal.sessionId,aal:principal.aal});return {pairingToken,expiresAt};
  },false),
  pair:async(input:{pairingToken:string;name:string;platform:"windows"|"macos"|"linux"})=>{const deviceToken=randomToken(),deviceId=crypto.randomUUID();const device=await repository.pair({pairingHash:await sha256(input.pairingToken),tokenHash:await sha256(deviceToken),deviceId,name:input.name,platform:input.platform,now:now()});if(!device)fail(401,"pairing_unavailable","Pairing is expired or already used. Create a new pairing token.");return {deviceId,deviceToken};},
  devicePrincipal:async(credential:string)=>{const match=/^([a-f0-9-]{36})\.([a-f0-9]{64})$/.exec(credential);if(!match)fail(401,"device_unauthorized","A paired connector credential is required.");const principal=await repository.authenticateDevice(match[1]!,await sha256(match[2]!));if(!principal)fail(401,"device_unauthorized","The connector is not authorized. Pair it again.");return {principal,deviceId:match[1]!};},
  deploy:(principal:Principal,key:string,input:{strategyVersionId:string;deviceId:string;accountId:string;mode:"dry_run"|"paper";configurationHash:string})=>mutate(principal,key,"deployments",input,async(state,time)=>{
   if(state.deployments.filter(d=>d.state!=="retired"||!d.retiredAcknowledgedAt).length>=20)fail(409,"workspace_capacity","This workspace has reached its active deployment capacity.");const strategyVersion=state.configurations.find(v=>v.id===input.strategyVersionId);const device=state.devices.find(v=>v.id===input.deviceId&&!v.revokedAt);
   if(!strategyVersion||!device)fail(404,"not_found","The selected configuration or connector is unavailable.");if(strategyVersion.configurationHash!==input.configurationHash)fail(409,"configuration_mismatch","Review the current immutable configuration before deployment.");
   if(!device.accounts.some(a=>a.accountId===input.accountId&&a.environment==="SIMULATE"&&a.currency==="USD"))fail(422,"simulation_account_required","Select a simulated U.S. account discovered by this connector.");
   if(state.deployments.some(d=>d.accountId===input.accountId&&(d.state!=="retired"||!d.retiredAcknowledgedAt)))fail(409,"account_already_assigned","Retire and acknowledge the existing deployment before using this account again.");
   const value:DeploymentMandate={...input,id:crypto.randomUUID(),schemaVersion:"leo.deployment-mandate.v1",mandateVersion:1,state:"paused",createdAt:time,updatedAt:time,leaseGeneration:0,leaseExpiresAt:null,pauseReason:"New deployment; review and resume explicitly.",strategyVersion};state.deployments.push(value);return value;
  }),
  control:(principal:Principal,key:string,id:string,input:{action:"pause"|"resume";reason:string;expectedVersion:number})=>mutate(principal,key,`deployments/${id}/controls`,input,async(state,time)=>{
   const d=state.deployments.find(v=>v.id===id);if(!d)fail(404,"not_found","The deployment is unavailable.");if(d.state==="retired")fail(409,"deployment_retired","A retired mandate cannot be resumed.");if(d.mandateVersion!==input.expectedVersion)fail(409,"revision_conflict","The deployment changed. Refresh its status before retrying.");
   if(input.action==="resume"){const device=state.devices.find(v=>v.id===d.deviceId&&!v.revokedAt);if(!device?.lastSeenAt||Date.parse(time)-Date.parse(device.lastSeenAt)>LEASE_MS||!device.accounts.some(a=>a.accountId===d.accountId))fail(409,"connector_not_ready","Wait for a fresh, reconciled connector before resuming.");}
   return control(state,d,input.action,input.reason,time);
  }),
  retire:(principal:Principal,key:string,id:string,input:{reason:string;expectedVersion:number})=>mutate(principal,key,`deployments/${id}/retire`,input,async(state,time)=>{
   const d=state.deployments.find(v=>v.id===id);if(!d)fail(404,"not_found","The deployment is unavailable.");if(d.mandateVersion!==input.expectedVersion||d.state!=="paused")fail(409,"retirement_not_ready","Pause the current mandate and refresh before retiring it.");
   const paused=state.controls.some(c=>c.deploymentId===id&&c.action==="pause"&&c.mandateVersion===d.mandateVersion&&c.status==="applied");const last=state.evidence.filter(e=>e.deploymentId===id&&e.kind==="reconciliation").sort((a,b)=>Date.parse(b.occurredAt)-Date.parse(a.occurredAt))[0];
   if(!paused||!last||Date.parse(time)-Date.parse(last.occurredAt)>LEASE_MS||Date.parse(last.occurredAt)>Date.parse(time)||last.payload.consistent!==true||last.payload.positionsFlat!==true||last.payload.workingOrders!==0||last.payload.unknownOrders!==0)fail(409,"retirement_not_ready","Retirement needs an acknowledged pause and fresh proof of no positions, working orders, or unknown orders.");
   d.state="retired";d.mandateVersion++;d.leaseGeneration++;d.leaseExpiresAt=null;d.updatedAt=time;d.pauseReason=input.reason;
   const c:StrategyControl={id:crypto.randomUUID(),deploymentId:id,action:"retire",reason:input.reason,mandateVersion:d.mandateVersion,configurationHash:d.configurationHash,createdAt:time,status:"pending",acknowledgedAt:null};state.controls.push(c);return c;
  }),
  revoke:(principal:Principal,key:string,id:string,input:{reason:string})=>mutate(principal,key,`devices/${id}/revoke`,input,async(state,time)=>{const device=state.devices.find(v=>v.id===id);if(!device)fail(404,"not_found","The connector is unavailable.");device.revokedAt=time;for(const d of state.deployments.filter(v=>v.deviceId===id&&v.state!=="retired"))control(state,d,"pause",input.reason,time);return device;}),
  poll:(principal:Principal,deviceId:string,input:DevicePollInput)=>repository.transact(principal,async state=>{
   const time=now();expire(state,time);const device=state.devices.find(v=>v.id===deviceId&&!v.revokedAt);if(!device)fail(401,"device_unauthorized","The connector is unavailable.");if(input.sequence<=device.lastSequence)fail(409,"poll_replay","The poll sequence must increase across restarts.");
   if(device.instanceId&&device.instanceId!==input.instanceId&&device.lastSeenAt&&Date.parse(time)-Date.parse(device.lastSeenAt)<=LEASE_MS)fail(409,"device_instance_busy","Another connector process holds this device lease.");
   device.instanceId=input.instanceId;device.lastSequence=input.sequence;device.lastSeenAt=time;device.accounts=input.accounts;
   for(const ack of input.acks){const c=state.controls.find(v=>v.id===ack.controlId);const d=c?state.deployments.find(v=>v.id===c.deploymentId&&v.deviceId===deviceId):undefined;if(!c||!d||c.mandateVersion!==d.mandateVersion||c.status!=="pending")continue;c.status=ack.status;c.acknowledgedAt=time;if(ack.status==="rejected")control(state,d,"pause","Connector rejected the current control; review required.",time);else if(c.action==="retire")d.retiredAcknowledgedAt=time;}
   const leaseExpiresAt=new Date(Date.parse(time)+LEASE_MS).toISOString();const deployments=state.deployments.filter(d=>d.deviceId===deviceId);
   for(const d of deployments){if(!device.accounts.some(a=>a.accountId===d.accountId)&&d.state==="running")control(state,d,"pause","The simulated account is no longer present.",time);const resumed=state.controls.some(c=>c.deploymentId===d.id&&c.mandateVersion===d.mandateVersion&&c.action==="resume"&&c.status==="applied");d.leaseExpiresAt=d.state==="running"&&resumed?leaseExpiresAt:null;}
   return {serverTime:time,leaseExpiresAt,deployments,controls:state.controls.filter(c=>deployments.some(d=>d.id===c.deploymentId&&d.mandateVersion===c.mandateVersion)&&c.status==="pending")};
  }),
  events:(principal:Principal,deviceId:string,key:string,input:{events:EvidenceEvent[]})=>mutate(principal,key,"device/events",input,async(state,time)=>{
   for(const event of input.events){
    if(event.kind==="research_result"||event.researchRunId!==undefined)fail(422,"report_route_required","Research results must use the validated report upload route.");
    const d=state.deployments.find(v=>v.id===event.deploymentId&&v.deviceId===deviceId);if(!d)fail(404,"not_found","The deployment is unavailable.");
    if(!secretFree(event.payload)||JSON.stringify(event.payload).length>16384)fail(422,"invalid_evidence","Evidence must be bounded and contain no credentials.");
    if(Date.parse(event.occurredAt)>Date.parse(time)+300000)fail(422,"future_evidence","Evidence cannot be dated in the future.");
    const prior=state.evidence.find(v=>v.id===event.id)??await state.lookupRecord?.("evidence",event.id);
    if(prior){if(canonical(prior)!==canonical(event))fail(409,"event_replay_conflict","The event identifier already refers to different content.");continue;}
    const sameSequence=state.evidence.find(v=>v.deploymentId===event.deploymentId&&v.sequence===event.sequence)??await state.lookupSequence?.(d.id,event.sequence);
    if(sameSequence)fail(409,"event_sequence_conflict","An evidence sequence number already belongs to another event.");
    state.evidence.push(event);if((event.kind==="incident"||(event.kind==="reconciliation"&&event.payload.consistent===false))&&d.state!=="retired"&&(d.state==="running"||!state.controls.some(c=>c.deploymentId===d.id&&c.mandateVersion===d.mandateVersion&&c.action==="pause")))control(state,d,"pause","Connector reported an incident or reconciliation mismatch.",time);
   }
   return {accepted:input.events.map(e=>e.id)};
  }),
  research:(principal:Principal,key:string,input:{strategyVersionId:string})=>mutate(principal,key,"research-runs",input,async(state,time)=>{
   if(!state.configurations.some(v=>v.id===input.strategyVersionId))fail(404,"not_found","The configuration is unavailable.");const run={schemaVersion:"leo.research-run.v1" as const,id:crypto.randomUUID(),strategyVersionId:input.strategyVersionId,status:"blocked" as const,createdAt:time,reason:"Awaiting a baseline research report from the local CLI using observed, verified source data. Import the report to review exploratory results.",evidenceEventId:null};state.researchRuns.push(run);return run;
  }),
  uploadReport:(principal:Principal,key:string,runId:string,input:{report:ResearchReport},deviceId?:string)=>mutate(principal,key,`research-runs/${runId}/report`,input,async(state,time)=>{
   if(deviceId&&!state.devices.some(d=>d.id===deviceId&&!d.revokedAt))fail(401,"device_unauthorized","The connector is unavailable.");
   const run=state.researchRuns.find(r=>r.id===runId)??await state.lookupRecord?.("research_run",runId) as ResearchRun|undefined;if(!run)fail(404,"not_found","The research run is unavailable.");if(run.evidenceEventId)fail(409,"report_exists","This research run already has an immutable report. Create another run.");
   const config=state.configurations.find(c=>c.id===run.strategyVersionId);if(!config)fail(404,"not_found","The configuration is unavailable.");const parsed=researchReportInputSchema.safeParse(input);if(!parsed.success||!secretFree(input)||JSON.stringify(input).length>49152||/"(?:bars|input_manifest)"\s*:/.test(JSON.stringify(input)))fail(422,"invalid_report","Import a bounded baseline research report, without raw history or credentials.");
   const report=parsed.data.report;if(report.strategy!==config.strategyId||report.symbol!==config.symbol)fail(409,"report_configuration_mismatch","The report strategy and symbol must match this immutable configuration.");
   const evidence:EvidenceEvent={schemaVersion:"leo.evidence-event.v1",id:crypto.randomUUID(),deploymentId:null,researchRunId:runId,kind:"research_result",occurredAt:time,sequence:0,payload:{report,provenance:"user_supplied_local_report",artifactVerifiedByServer:false}};
   state.evidence.push(evidence);run.status="completed";run.reason="Local report imported for exploratory review. The server has not independently reproduced its artifact. No execution or promotion is authorized by this report.";run.evidenceEventId=evidence.id;if(!state.researchRuns.some(r=>r.id===runId))state.researchRuns.push(run);return {run,evidence};
  }),
  explanation:async(principal:Principal,input:{deploymentId?:string|undefined;question:string},key:string=crypto.randomUUID()):Promise<Explanation>=>{
   const requestHash=await sha256(canonical({path:"explanations",body:input}));
   const context=await repository.transact(principal,async state=>{const prior=state.idempotency.find(i=>i.id===key)??await state.lookupRecord?.("idempotency",key) as Idempotency|undefined;if(prior){if(prior.requestHash!==requestHash)fail(409,"idempotency_conflict","That request key was used for different content.");const replay=state.explanations.find(e=>e.id===key)??await state.lookupRecord?.("explanation",key) as Explanation|undefined;if(replay)return {replay,deployment:null,evidence:[]};fail(409,"explanation_pending","That explanation request has already started. Wait for its response or submit a new request.");}const deployment=input.deploymentId?state.deployments.find(d=>d.id===input.deploymentId)??null:null;if(input.deploymentId&&!deployment)fail(404,"not_found","The deployment is unavailable.");state.idempotency.push({id:key,requestHash,response:null,replayable:false,createdAt:now()});return {replay:null,deployment,evidence:state.evidence.filter(e=>!input.deploymentId||e.deploymentId===input.deploymentId).slice(-30)};});
   if(context.replay)return context.replay;
   let answer:Explanation={id:key,answer:"The explanation provider is not configured. Review the recorded evidence below; no model explanation was generated.",evidenceIds:context.evidence.map(e=>e.id),createdAt:now(),providerStatus:"unavailable"};
   if(options.supervisor)try{const response=await options.supervisor.explain({question:input.question,deployment:context.deployment,evidence:context.evidence});const validIds=new Set(context.evidence.map(e=>e.id));answer={id:key,answer:response.answer,evidenceIds:response.evidenceIds.filter(id=>validIds.has(id)),createdAt:now(),providerStatus:"available"};if(response.pauseRequest){const parsed=pauseRequestSchema.safeParse(response.pauseRequest);if(parsed.success&&parsed.data.deploymentId===context.deployment?.id&&parsed.data.evidenceIds.every(id=>validIds.has(id)))answer.pauseRequest=parsed.data;}}catch{answer.answer="The explanation provider is unavailable. No model control was applied.";answer.evidenceIds=[];}
   // Provider latency never holds the owner lock. Recheck the exact revision
   // afterwards; a late explanation cannot override a newer user decision.
   return repository.transact(principal,async state=>{if(answer.pauseRequest){const d=state.deployments.find(d=>d.id===answer.pauseRequest!.deploymentId);if(d&&d.state!=="retired"&&d.mandateVersion===context.deployment?.mandateVersion){const c=control(state,d,"pause",answer.pauseRequest.reason,now());answer.pauseControlId=c.id;}}state.explanations.push(answer);return answer;});
  }
 };
}

