const assert=require('node:assert/strict');
const fs=require('node:fs/promises');
const path=require('node:path');
const {chromium}=require(process.env.LEO_PLAYWRIGHT_MODULE || 'playwright');
const {fixtureStatus,fixtureReport}=require('./fixtures.ts');
const output=path.resolve(__dirname,'../../../.impeccable/review/strategy-lab');
const root='http://127.0.0.1:3117/';
const project='https://katwbobjiyzipqlzarus.supabase.co';
const fixtureConfig={schemaVersion:'strategy-public-config/v1',enabled:true,supabaseUrl:project,publishableKey:'sb_publishable_test',apiUrl:project+'/functions/v1/strategy-api'};

(async()=>{
  await fs.mkdir(output,{recursive:true});
  const browser=await chromium.launch({headless:true});
  const results={evidence:'injected browser API fixtures only; no broker calls',checks:[],errors:[]};
  try{
    const context=await browser.newContext({viewport:{width:1536,height:960},deviceScaleFactor:1});
    context.setDefaultTimeout(15000);
    const page=await context.newPage();
    page.on('pageerror',error=>results.errors.push(error.message));
    // Deliberately fail the archived charts; controls must remain accessible.
    await page.route('**/app/research-desk/data/**',route=>route.fulfill({status:503,body:'injected chart outage'}));
    await page.goto(root+'#/strategies');
    await page.getByRole('heading',{name:'Choose strategy',exact:true}).waitFor();
    await page.getByText('Account connections awaiting release setup',{exact:true}).waitFor();
    await page.getByRole('button',{name:'Configure mean reversion',exact:true}).click();
    assert.equal(await page.locator('#strategy-step-title').evaluate(element=>element===document.activeElement),true);
    await page.getByLabel('U.S. stock or ETF symbol',{exact:false}).fill('AAPL');
    assert.equal(await page.getByRole('button',{name:'Save revision',exact:true}).isDisabled(),true);
    await page.getByRole('button',{name:'1 Choose strategy',exact:true}).click();
    await page.evaluate(()=>document.fonts.ready);
    await page.screenshot({path:path.join(output,'desktop.png'),fullPage:true,animations:'disabled'});
    await page.setViewportSize({width:390,height:844});
    await page.screenshot({path:path.join(output,'mobile.png'),fullPage:true,animations:'disabled'});
    assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
    for(const button of await page.locator('.strategy-steps button').all())assert(await button.evaluate(element=>{const bounds=element.getBoundingClientRect();return bounds.left>=0&&bounds.right<=innerWidth;}));
    await page.getByRole('button',{name:'3 Review evidence',exact:true}).click();
    await page.getByRole('button',{name:'Connect computer',exact:true}).focus();
    await page.keyboard.press('Enter');
    assert.equal(await page.locator('#strategy-step-title').evaluate(element=>element===document.activeElement),true);
    await page.evaluate(()=>scrollTo(0,0));
    await page.screenshot({path:path.join(output,'connect-mobile.png'),fullPage:true,animations:'disabled'});
    await page.getByRole('button',{name:'Review authorization',exact:true}).focus();
    await page.keyboard.press('Enter');
    assert.equal(await page.locator('#strategy-step-title').evaluate(element=>element===document.activeElement),true);
    assert(await page.locator('#strategy-step-title').evaluate(element=>{const bounds=element.getBoundingClientRect();return bounds.top>=0&&bounds.bottom<=innerHeight;}));
    await page.evaluate(()=>scrollTo(0,0));
    await page.screenshot({path:path.join(output,'authorize-mobile.png'),fullPage:true,animations:'disabled'});
    results.checks.push('Keyboard step transitions focus and reveal the new heading; all five mobile steps fit; CTA navigation reaches steps four and five');
    results.checks.push('Signed-out rule exploration, disabled authenticated writes, desktop/mobile without horizontal overflow, chart outage independence');
    await context.close();

    const signed=await browser.newContext({viewport:{width:1536,height:960}});
    signed.setDefaultTimeout(15000);
    let state=fixtureStatus(); let unavailable=false; const requests=[];
    const user={id:state.membership.userId,aud:'authenticated',role:'authenticated',email:'test-user@example.invalid',email_confirmed_at:new Date().toISOString(),app_metadata:{provider:'google'},user_metadata:{},identities:[],created_at:new Date().toISOString(),is_anonymous:false};
    const payload=Buffer.from(JSON.stringify({sub:user.id,exp:Math.floor(Date.now()/1000)+3600,role:'authenticated'})).toString('base64url');
    await signed.addInitScript(({user,payload})=>localStorage.setItem('leo.strategy-lab.auth.v1',JSON.stringify({access_token:`test.${payload}.signature`,refresh_token:'test-refresh',expires_in:3600,expires_at:Math.floor(Date.now()/1000)+3600,token_type:'bearer',user})),{user,payload});
    const monitor=await signed.newPage(); monitor.on('pageerror',error=>results.errors.push(error.message));
    await monitor.route('**/app/research-desk/strategy-config.json',route=>route.fulfill({json:fixtureConfig}));
    await monitor.route('**/app/research-desk/data/**',route=>route.fulfill({status:503,body:'injected chart outage'}));
    await monitor.route(project+'/**',async route=>{
      const respond=options=>route.fulfill({...options,headers:{'Access-Control-Allow-Origin':'http://127.0.0.1:3117','Access-Control-Allow-Headers':'authorization,apikey,content-type,idempotency-key,x-client-info','Access-Control-Allow-Methods':'GET,POST,OPTIONS'}});
      const request=route.request();
      if(request.method()==='OPTIONS'){await respond({status:204});return;} const url=new URL(request.url());
      if(url.pathname.endsWith('/auth/v1/logout')){await respond({status:204});return;}
      if(url.pathname.endsWith('/v1/status')){await respond(unavailable?{status:503,json:{error:'injected outage'}}:{json:{data:state,meta:{requestId:'test'}}});return;}
      if(url.pathname.endsWith('/v1/configurations')){
        const body=request.postDataJSON();assert.deepEqual(body,{strategyId:'MR-v1',symbol:'MSFT',parameters:{}});
        const item={...state.configurations[0],id:'20000000-0000-4000-8000-000000000002',symbol:'MSFT',symbols:['MSFT'],configurationHash:'e'.repeat(64)};
        state.configurations.push(item);await respond({json:{data:item}});return;
      }
      if(url.pathname.endsWith('/v1/research-runs')){
        const run={schemaVersion:'leo.research-run.v1',id:'70000000-0000-4000-8000-000000000001',strategyVersionId:state.configurations[1].id,status:'blocked',createdAt:new Date().toISOString(),reason:'Local validated history required.',evidenceEventId:null};
        state.researchRuns.push(run);await respond({json:{data:run}});return;
      }
      if(url.pathname.endsWith('/report')){
        assert.deepEqual(request.postDataJSON(),{report:fixtureReport()});
        const run=state.researchRuns[0];run.status='completed';run.evidenceEventId='50000000-0000-4000-8000-000000000004';
        const evidence={schemaVersion:'leo.evidence-event.v1',id:run.evidenceEventId,deploymentId:null,researchRunId:run.id,kind:'research_result',occurredAt:new Date().toISOString(),sequence:0,payload:{report:fixtureReport()}};
        state.evidence.push(evidence);await respond({json:{data:{run,evidence}}});return;
      }
      if(url.pathname.endsWith('/v1/pairing')){await respond({json:{data:{pairingToken:'f'.repeat(64),expiresAt:new Date(Date.now()+300000).toISOString()}}});return;}
      if(url.pathname.endsWith('/v1/deployments')){
        const body=request.postDataJSON();assert.equal(body.mode,'dry_run');assert.equal(body.accountId,'TEST-PAPER-001');
        const mandate={...state.deployments[0],...body,id:'40000000-0000-4000-8000-000000000002',state:'paused',leaseExpiresAt:null,strategyVersion:state.configurations[1]};
        state.deployments.push(mandate);await respond({json:{data:mandate}});return;
      }
      if(url.pathname.endsWith('/v1/explanations')){
        assert.equal(request.postDataJSON().deploymentId,state.deployments[0].id);
        await respond({json:{data:{id:'80000000-0000-4000-8000-000000000001',answer:'Recorded RSI condition was not met. Injected test explanation.',evidenceIds:[state.evidence[1].id],createdAt:new Date().toISOString(),providerStatus:'unavailable'}}});return;
      }
      if(url.pathname.endsWith('/controls')){
        const body=request.postDataJSON();requests.push({body,key:request.headers()['idempotency-key']});
        const d=state.deployments[0]; const control={id:'60000000-0000-4000-8000-000000000001',deploymentId:d.id,action:body.action,reason:body.reason,mandateVersion:2,configurationHash:d.configurationHash,createdAt:new Date().toISOString(),status:'pending',acknowledgedAt:null};
        state={...state,deployments:[{...d,state:'paused',mandateVersion:2}],controls:[control]};
        await respond({json:{data:control}});return;
      }
      await respond({status:404,json:{error:'unexpected mocked API request'}});
    });
    await monitor.goto(root+'#/strategies');
    await monitor.getByText('Identity verified · brokerage credentials stay on your computer',{exact:true}).waitFor({timeout:10000}).catch(async error=>{console.log(await monitor.locator('.strategy-workspace').innerText());throw error;});
    await monitor.getByRole('button',{name:'Configure mean reversion',exact:true}).click();
    await monitor.getByLabel('U.S. stock or ETF symbol',{exact:false}).fill('MSFT');
    await monitor.getByRole('button',{name:'Save revision',exact:true}).click();
    await monitor.getByRole('heading',{name:'Review evidence',exact:true}).waitFor();
    await monitor.getByRole('button',{name:'Request historical evaluation',exact:true}).click();
    await monitor.getByLabel('Import the local research report').setInputFiles({name:'injected-report.json',mimeType:'application/json',buffer:Buffer.from(JSON.stringify(fixtureReport()))});
    await monitor.getByText('Exploratory · not promoted',{exact:true}).waitFor();
    await monitor.getByRole('button',{name:'Connect computer',exact:true}).click();
    await monitor.getByRole('button',{name:'Create pairing token',exact:true}).click();
    assert.equal(await monitor.getByLabel('Single-use pairing token').inputValue(),'f'.repeat(64));
    await monitor.getByRole('button',{name:'Review authorization',exact:true}).click();
    await monitor.getByRole('combobox',{name:/Paired computer/}).selectOption(state.devices[0].id);
    await monitor.getByRole('combobox',{name:/Paper account/}).selectOption('TEST-PAPER-001');
    await monitor.getByRole('checkbox').check();
    await monitor.getByRole('button',{name:'Create paused dry-run mandate',exact:true}).click();
    await monitor.getByText('Mandate saved and paused. Resume after the connector completes reconciliation.',{exact:true}).waitFor();
    results.checks.push('Authenticated revision, research request and validated summary import, single-use pairing display, explicit dry-run mandate authorization');
    await monitor.getByRole('button',{name:'1 Choose strategy',exact:true}).click();
    await monitor.getByRole('button',{name:'Pause entries',exact:true}).first().click();
    await monitor.getByText('Pause requested',{exact:true}).waitFor();
    assert.equal(requests.length,1);assert(requests[0].key);assert.equal(requests[0].body.expectedVersion,1);
    await monitor.screenshot({path:path.join(output,'pending-desktop.png'),fullPage:true,animations:'disabled'});
    unavailable=true;
    await monitor.getByRole('button',{name:'Refresh connector status'}).click();
    await monitor.getByText('Connection interrupted',{exact:true}).waitFor();
    assert.equal(await monitor.getByText('Test computer',{exact:true}).count(),1);
    await monitor.getByText('Protection unavailable',{exact:true}).waitFor();
    for(const button of await monitor.getByRole('button',{name:'Request resume',exact:true}).all())assert.equal(await button.isDisabled(),true);
    await monitor.setViewportSize({width:390,height:844});
    await monitor.screenshot({path:path.join(output,'stale-mobile.png'),fullPage:true,animations:'disabled'});
    assert(await monitor.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
    results.checks.push('Verified mocked session, one idempotent pause request, pending acknowledgement, stale-value preservation, stale protection warning, resume blocked');
    unavailable=false;
    state.controls[0].status='applied';state.controls[0].acknowledgedAt=new Date().toISOString();
    await monitor.getByRole('button',{name:'Refresh connector status'}).click();
    await monitor.getByText('Entries paused',{exact:true}).first().waitFor();
    await monitor.getByRole('button',{name:'Sign out',exact:true}).click();
    await monitor.getByRole('button',{name:'Sign in with Google',exact:true}).waitFor();
    assert.equal(await monitor.getByText('Test computer',{exact:true}).count(),0);
    results.checks.push('Acknowledged pause and sign-out clears owner data');
    await signed.close();
    assert.deepEqual(results.errors,[]);
    await fs.writeFile(path.join(output,'browser-checks.json'),JSON.stringify(results,null,2));
    console.log(JSON.stringify(results,null,2));
  }finally{await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
