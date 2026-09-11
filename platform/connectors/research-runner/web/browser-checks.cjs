/* Local operational evidence only. Stale/network states are explicit browser injections. */
const assert=require('node:assert/strict');
const fs=require('node:fs/promises');
const path=require('node:path');
const {chromium}=require(process.env.LEO_PLAYWRIGHT_MODULE||'C:/Users/Hj/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root='http://127.0.0.1:3119';
const output=path.resolve(__dirname,'../../../.impeccable/review/continuous-research');
const receipt={checkedAt:new Date().toISOString(),scope:'Actual local source-readiness worker and research controls; not broker or performance evidence.',checks:[],screenshots:[],injections:[],errors:[]};
async function check(name,action){await action();receipt.checks.push({name,result:'pass'});console.log('PASS '+name);}
(async()=>{
 await fs.mkdir(output,{recursive:true});const browser=await chromium.launch({headless:true});
 try {
  const desktop=await browser.newContext({viewport:{width:1440,height:900},reducedMotion:'reduce'});
  const page=await desktop.newPage();page.on('pageerror',error=>receipt.errors.push(error.message));page.setDefaultTimeout(16000);
  await page.goto(root);await page.getByText('recorded-market-history',{exact:true}).waitFor();
  const capture=async(page,name)=>{await page.evaluate(async()=>{await document.fonts.ready;scrollTo(0,0);});assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));const file=path.join(output,name+'.png');await page.screenshot({path:file,fullPage:true,animations:'disabled'});receipt.screenshots.push({name,path:file,viewport:page.viewportSize()});};
  await check('Actual worker heartbeat, source batch, zero replay/AI claims and six source records',async()=>{
   await page.waitForFunction(()=>document.body.dataset.stale==='false');
   assert.equal(await page.locator('#ai').innerText(),'0');assert.equal(await page.locator('#completed').innerText(),'0');
   assert.equal(await page.locator('.coverage-row').count(),6);await page.getByText('More evidence needed',{exact:true}).waitFor();
   await capture(page,'desktop');
  });
  await check('Research pause waits for worker acknowledgment and resume restores monitoring',async()=>{
   await page.getByRole('button',{name:'Pause research',exact:true}).click();
   await page.getByRole('button',{name:'Resume research',exact:true}).waitFor();
   await page.getByRole('heading',{name:'Research is paused.',exact:true}).waitFor();
   await page.getByRole('button',{name:'Resume research',exact:true}).click();
   await page.getByRole('button',{name:'Pause research',exact:true}).waitFor();
   await page.waitForFunction(()=>document.getElementById('state').textContent==='Watching for new data');
  });
  const mobile=await browser.newContext({viewport:{width:390,height:844},reducedMotion:'reduce'});const phone=await mobile.newPage();phone.setDefaultTimeout(16000);phone.on('pageerror',error=>receipt.errors.push(error.message));await phone.goto(root);await phone.locator('.coverage-row').first().waitFor();
  await check('Mobile history disclosures and keyboard controls fit without horizontal overflow',async()=>{
   const first=phone.locator('.coverage-row summary').first();await first.focus();await phone.keyboard.press('Enter');
   assert(await phone.locator('.coverage-row').first().evaluate(node=>node.open));
   for(const text of ['split-adjustment policy','exchange-session coverage','each historical bar'])await phone.getByText(text,{exact:false}).first().waitFor();
   await capture(phone,'mobile');
  });
  await check('Stale heartbeat retains real last values and disables resume',async()=>{
   const response=await page.request.get(root+'/api/status');const data=await response.json();
   const injected={...data,fresh:false,heartbeat_age_seconds:90};
   await mobile.route('**/api/status',route=>route.fulfill({json:injected}));await phone.getByRole('button',{name:'Refresh',exact:true}).click();
   await phone.getByRole('heading',{name:'The worker needs a check.',exact:true}).waitFor();
   assert(await phone.locator('#control').isDisabled());assert.equal(await phone.locator('.coverage-row').count(),6);
   await capture(phone,'mobile-stale');receipt.injections.push('Browser-only status fresh=false, heartbeat_age_seconds=90; worker itself unchanged.');
  });
  await check('Network outage preserves values and offers manual refresh',async()=>{
   await mobile.unroute('**/api/status');await mobile.route('**/api/status',route=>route.abort());await phone.getByRole('button',{name:'Refresh',exact:true}).click();
   await phone.getByRole('heading',{name:'The monitor is disconnected.',exact:true}).waitFor();
   assert.equal(await phone.locator('.coverage-row').count(),6);assert(await phone.locator('#control').isDisabled());
   receipt.injections.push('Browser-only /api/status request abort; actual worker and source retained.');
  });
  await check('Strategy workspace exposes the local monitor independently of cloud account setup',async()=>{
   await page.goto('http://127.0.0.1:3117/#/strategies');const link=page.getByRole('link',{name:'Open local monitor',exact:true});await link.waitFor();assert.equal(await link.getAttribute('href'),root+'/');
  });
  assert.deepEqual(receipt.errors,[]);await desktop.close();await mobile.close();
 }catch(error){receipt.failure=error.stack;throw error;}
 finally{await browser.close();await fs.writeFile(path.join(output,'browser-checks.json'),JSON.stringify(receipt,null,2)+'\n');}
})().catch(error=>{console.error(error);process.exitCode=1;});
