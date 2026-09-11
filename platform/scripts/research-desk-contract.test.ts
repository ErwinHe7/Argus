import {test} from 'node:test';
import assert from 'node:assert/strict';
import {safeReturn,parseRecords} from '../features/research-desk/storage';
test('return links cannot leave the current origin or forward account parameters',()=>{
  const origin='https://leo.axio7.workers.dev';
  assert.equal(safeReturn('https://evil.example/app/#/discover',origin),`${origin}/app/?preview=1#/discover`);
  assert.equal(safeReturn(`${origin}/app/?preview=1&access_token=secret&v=abc#/discover`,origin),`${origin}/app/?preview=1&v=abc#/discover`);
  assert.equal(safeReturn(`${origin}/api/delete#/you`,origin),`${origin}/app/?preview=1#/discover`);
});
test('invalid local journal data does not become a record',()=>{
  assert.deepEqual(parseRecords('{bad'),[]);assert.deepEqual(parseRecords('[{"kind":"positions","symbol":"AVGO"}]'),[]);
  assert.deepEqual(parseRecords('{"records":[]}'),[]);
});
