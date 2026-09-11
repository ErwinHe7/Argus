import { test } from 'node:test';
import assert from 'node:assert/strict';
import { publicConfigSchema, callbackLocation, authReturnPath } from '../config';
import config from '../strategy-config.example.json';
import { accountEvidence, controlLabel, latestEvidence, safeValue } from '../state';
import { parseStatus, StrategyClient, StrategyApiError } from '../client';
import { fixtureStatus } from './fixtures';
import type { SupabaseClient } from '@supabase/supabase-js';

test('public configuration rejects secret credentials and foreign token destinations', () => {
  assert.equal(publicConfigSchema.safeParse(config).success, true);
  assert.equal(publicConfigSchema.safeParse({...config,enabled:true,publishableKey:'sb_secret_test'}).success, false);
  assert.equal(publicConfigSchema.safeParse({...config,apiUrl:'https://attacker.example/api'}).success, false);
  const payload=btoa(JSON.stringify({role:'service_role',ref:'katwbobjiyzipqlzarus'}));
  assert.equal(publicConfigSchema.safeParse({...config,enabled:true,publishableKey:`header.${payload}.signature`}).success,false);
  assert.equal(publicConfigSchema.safeParse({...config,enabled:true,publishableKey:'sb_publishable_test'}).success,true);
});
test('callback consumes codes only on the exact callback route', () => {
  assert.deepEqual(callbackLocation('https://leo.axio7.workers.dev/strategy-auth/callback?code=once'),{code:'once',failed:false});
  assert.deepEqual(callbackLocation('https://leo.axio7.workers.dev/strategy-auth/callback/nested?code=once'),{code:null,failed:false});
  assert.deepEqual(callbackLocation('https://leo.axio7.workers.dev/strategy-auth/callback?error=access_denied'),{code:null,failed:true});
  assert.deepEqual(callbackLocation('https://leoinvesting.com/strategy-auth/callback#error=access_denied'),{code:null,failed:true});
});
test('OAuth return paths cannot leave the public homepage or strategy workspace', () => {
  assert.equal(authReturnPath('/#/strategies'), '/#/strategies');
  for (const input of [null, '/#/home', 'https://evil.example', '//evil.example', '/#/strategies?redirect=https://evil.example', '/app/', 'javascript:alert(1)']) {
    assert.equal(authReturnPath(input), '/#/home');
  }
});
test('pause remains requested until acknowledgement and an expired lease cannot show Running', () => {
  const s=fixtureStatus('2026-09-07T14:00:00Z'); const d=s.deployments[0]!;
  assert.equal(controlLabel(d,[],Date.parse(d.createdAt)),'Running');
  assert.equal(controlLabel(d,[],Date.parse(d.createdAt)+16000),'Authorization expired');
  const control={id:'60000000-0000-4000-8000-000000000001',deploymentId:d.id,action:'pause' as const,reason:'Test',mandateVersion:2,configurationHash:d.configurationHash,createdAt:d.createdAt,status:'pending' as const,acknowledgedAt:null};
  assert.equal(controlLabel({...d,state:'paused'},[control],Date.parse(d.createdAt)),'Pause requested');
  assert.equal(controlLabel({...d,state:'paused'},[{...control,status:'applied'}],Date.parse(d.createdAt)),'Entries paused');
});
test('status rejects real-money mandates and nonmembers; missing account values remain missing', () => {
  assert.equal(parseStatus(fixtureStatus()).membership.status,'active');
  const live=fixtureStatus(); (live.deployments[0] as unknown as {mode:string}).mode='live';
  assert.throws(()=>parseStatus(live));
  assert.throws(()=>parseStatus({...fixtureStatus(),membership:{userId:'guest',status:'guest'}}));
  assert.equal(safeValue(null),'Not reported'); assert.equal(safeValue(0),'0');
  assert.equal(latestEvidence(fixtureStatus().evidence,'heartbeat','another-owner'),undefined);
});
test('requests carry a stable idempotency key, never follow redirects, and sanitize failures', async () => {
  const requests:RequestInit[]=[];
  const auth={auth:{getSession:async()=>({data:{session:{access_token:'test-token',user:{is_anonymous:false}}},error:null})}} as unknown as SupabaseClient;
  const client=new StrategyClient(publicConfigSchema.parse({...config,enabled:true,publishableKey:'sb_publishable_test'}),auth,async(_url,init)=>{requests.push(init!);return new Response(JSON.stringify({error:{message:'secret provider credentials'}}),{status:503});});
  await assert.rejects(client.pairing('stable-key'),(error:unknown)=>error instanceof StrategyApiError && !error.message.includes('credentials'));
  assert.equal(requests[0]!.redirect,'error');
  assert.equal((requests[0]!.headers as Record<string,string>)['Idempotency-Key'],'stable-key');
});
test('an explicit connector outage retains prior equity without presenting missing data as zero', () => {
  const s=fixtureStatus('2026-09-07T14:00:00Z'); const heartbeat=s.evidence[0]!;
  const outage={...heartbeat,id:'50000000-0000-4000-8000-000000000004',sequence:4,occurredAt:'2026-09-07T14:01:00Z',payload:{preserveLastVerifiedValues:true,equity:null,protectionStatus:'unavailable'}};
  const result=accountEvidence([...s.evidence,outage],s.deployments[0]!.id);
  assert.equal(result.retained,true);assert.equal(result.values?.payload.equity,'100000.00');
  assert.equal(result.current?.payload.protectionStatus,'unavailable');
  assert.equal(accountEvidence([outage],s.deployments[0]!.id).values,undefined);
});
