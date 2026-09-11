import assert from 'node:assert/strict';
import { test } from 'node:test';
import { allowedPath, authorizeLocalRequest, issueSession, validatePersonalBody, verifySession } from '../lib/personal-broker/boundary';

const config = { enabled: true, origin: 'http://127.0.0.1:3001', secret: 'test-secret-not-a-credential-'.repeat(3) };
const headers = () => new Headers({host:'127.0.0.1:3001', origin:config.origin, 'sec-fetch-site':'same-origin'});

test('personal requests require exact loopback origin and reject remote/proxied/cross-site access', () => {
  assert.equal(authorizeLocalRequest(headers(), 'POST', config), true);
  const nextHeaders=headers(); nextHeaders.set('x-forwarded-host','127.0.0.1:3001'); assert.equal(authorizeLocalRequest(nextHeaders,'POST',config),true);
  for (const [key,value] of [['origin','https://attacker.example'],['host','attacker.example'],['sec-fetch-site','cross-site'],['x-forwarded-host','attacker.example'],['x-forwarded-for','192.0.2.1']]) {
    const bad = headers(); bad.set(key,value); assert.equal(authorizeLocalRequest(bad,'POST',config),false,key);
  }
  const noOrigin=headers(); noOrigin.delete('origin'); assert.equal(authorizeLocalRequest(noOrigin,'POST',config),false);
  assert.equal(authorizeLocalRequest(headers(),'GET',{...config,enabled:false}),false);
  assert.equal(authorizeLocalRequest(headers(),'GET',{...config,origin:'https://public.example'}),false);
});

test('local session identity is signed, expires, and does not accept a foreign runtime key', () => {
  const now=Date.parse('2026-09-05T12:00:00Z'); const cookie=issueSession(config.secret,now);
  assert.match(verifySession(cookie,config.secret,now)!,/^[a-f0-9]{64}$/);
  assert.equal(verifySession(cookie,config.secret,now+28800_000),null);
  assert.equal(verifySession(cookie,'different-secret'.repeat(4),now),null);
  assert.equal(verifySession(cookie.replace(/^./,cookie[0]==='a'?'b':'a'),config.secret,now),null);
  const renewed = issueSession(config.secret,now+1000);
  assert.notEqual(cookie,renewed);
  assert.equal(verifySession(cookie,config.secret,now+1000),verifySession(renewed,config.secret,now+1000));
});

test('broker proxy cannot forward arbitrary endpoints or unreviewed order execution', () => {
  for (const path of [['orders'],['http:','attacker'],['..','orders'],['commands','../status'],['unlock','extra']]) assert.equal(allowedPath('POST',path),null);
  assert.equal(allowedPath('POST',['confirm']),'/confirm');
  assert.equal(allowedPath('GET',['commands','a'.repeat(32)]),`/commands/${'a'.repeat(32)}`);
  assert.equal(allowedPath('POST',['previews','a'.repeat(32),'discard']),`/previews/${'a'.repeat(32)}/discard`);
  assert.deepEqual(validatePersonalBody(`/previews/${'a'.repeat(32)}/discard`,{}),{});
  assert.equal(validatePersonalBody(`/previews/${'a'.repeat(32)}/discard`,{force:true}),null);
  assert.equal(validatePersonalBody('/confirm',{preview_id:'a'.repeat(32),confirmed:false}),null);
  assert.equal(validatePersonalBody('/confirm',{preview_id:'a'.repeat(32),confirmed:true,quantity:'2'}),null);
});

test('exact string quantities and prices cross the boundary without coercion or rounding', () => {
  const intent={symbol:'AAPL',side:'BUY',quantity:'1',limit_price:'100.01'};
  assert.deepEqual(validatePersonalBody('/previews',intent),intent);
  for (const changed of [{quantity:1},{quantity:'1e2'},{quantity:'0'},{limit_price:'0.00'},{limit_price:'1.001'},{symbol:'US.AAPL/../../'},{side:'SHORT'},{url:'http://elsewhere'}]) assert.equal(validatePersonalBody('/previews',{...intent,...changed}),null);
  assert.equal(validatePersonalBody('/connect',{account_id:123,mode:'REAL'}),null);
  assert.deepEqual(validatePersonalBody('/connect',{account_id:'9007199254740993',mode:'REAL'}),{account_id:'9007199254740993',mode:'REAL'});
});
