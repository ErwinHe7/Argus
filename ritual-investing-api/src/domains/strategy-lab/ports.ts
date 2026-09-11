import type { VerifiedRequestClaims } from "../../db/request-claims.ts";
import type { ConnectorDevice, DeploymentMandate, EvidenceEvent, Explanation, ResearchRun, StrategyControl, StrategyVersion } from "./contracts.ts";
export type Principal=VerifiedRequestClaims;
export type Pairing={id:string;tokenHash:string;expiresAt:string;consumedAt:string|null;sessionId:string;aal:"aal1"|"aal2"};
export type Idempotency={id:string;requestHash:string;response:unknown;replayable:boolean;createdAt:string};
export type Workspace={configurations:StrategyVersion[];deployments:DeploymentMandate[];devices:ConnectorDevice[];researchRuns:ResearchRun[];evidence:EvidenceEvent[];controls:StrategyControl[];pairings:Pairing[];idempotency:Idempotency[];explanations:Explanation[];lookupRecord?:(kind:string,id:string)=>Promise<unknown>;lookupSequence?:(deploymentId:string,sequence:number)=>Promise<unknown>};
export const emptyWorkspace=():Workspace=>({configurations:[],deployments:[],devices:[],researchRuns:[],evidence:[],controls:[],pairings:[],idempotency:[],explanations:[]});
export interface StrategyRepository {
  transact<T>(principal:Principal,fn:(state:Workspace)=>Promise<T>):Promise<T>;
  pair(input:{pairingHash:string;deviceId:string;tokenHash:string;name:string;platform:ConnectorDevice["platform"];now:string}):Promise<ConnectorDevice|null>;
  authenticateDevice(deviceId:string,tokenHash:string):Promise<Principal|null>;
}
export interface SupervisorProvider {explain(input:{question:string;evidence:EvidenceEvent[];deployment:DeploymentMandate|null}):Promise<Pick<Explanation,"answer"|"evidenceIds"|"pauseRequest">>}
export class StrategyError extends Error {constructor(public status:number,public code:string,public publicMessage:string){super(code);}}
