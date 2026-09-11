import {emptyWorkspace,StrategyError,type Principal,type StrategyRepository,type Workspace} from "../../src/domains/strategy-lab/ports.ts";
import type {ConnectorDevice} from "../../src/domains/strategy-lab/contracts.ts";
export function memoryRepository(now:()=>Date){
 const workspaces=new Map<string,Workspace>(),locks=new Map<string,Promise<void>>(),credentials=new Map<string,{hash:string;principal:Principal}>(),revoked=new Set<string>();
 const repository:StrategyRepository={
  async transact(principal,fn){if(revoked.has(principal.sessionId))throw new StrategyError(401,"session_inactive","Sign in again.");const previous=locks.get(principal.userId)??Promise.resolve();let release!:()=>void;const lock=new Promise<void>(resolve=>release=resolve);locks.set(principal.userId,previous.then(()=>lock));await previous;try{const state=structuredClone(workspaces.get(principal.userId)??emptyWorkspace());const result=await fn(state);workspaces.set(principal.userId,state);return structuredClone(result);}finally{release();}},
  async pair(input){for(const [owner,state]of workspaces){const pairing=state.pairings.find(p=>p.tokenHash===input.pairingHash);if(!pairing)continue;return repository.transact({userId:owner,sessionId:pairing.sessionId,aal:pairing.aal},async current=>{const pair=current.pairings.find(p=>p.id===pairing.id)!;if(pair.consumedAt||Date.parse(pair.expiresAt)<=now().getTime())return null;pair.consumedAt=now().toISOString();const device:ConnectorDevice={schemaVersion:"leo.connector-device.v1",id:input.deviceId,name:input.name,platform:input.platform,createdAt:input.now,lastSeenAt:null,revokedAt:null,lastSequence:0,instanceId:null,accounts:[]};current.devices.push(device);credentials.set(device.id,{hash:input.tokenHash,principal:{userId:owner,sessionId:pair.sessionId,aal:pair.aal}});return device;});}return null;},
  async authenticateDevice(id,hash){const c=credentials.get(id);return c&&c.hash===hash&&!revoked.has(c.principal.sessionId)?c.principal:null;}
 };
 return {repository,workspaces,revoked};
}
