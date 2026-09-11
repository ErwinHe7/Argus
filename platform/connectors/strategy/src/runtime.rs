use crate::{
    core::{self, Lease, money},
    protocol::*,
    store::Store,
};
use anyhow::{Context, Result, bail, ensure};
use chrono::Utc;
use fs2::FileExt;
use reqwest::blocking::Client;
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use std::{
    collections::{BTreeSet, HashMap, HashSet},
    fs::{File, OpenOptions},
    io::{BufRead, BufReader, Read, Write},
    path::{Path, PathBuf},
    process::{Child, ChildStdin, Command, Stdio},
    sync::{Arc, Mutex, mpsc},
    thread,
    time::{Duration, Instant},
};
use uuid::Uuid;

const MAX_RESPONSE: usize = 4 * 1024 * 1024;

#[derive(Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Config {
    pub api_base: String,
    pub device_id: String,
    pub engine_executable: PathBuf,
    pub adapter_executable: PathBuf,
    #[serde(default)]
    pub adapter_arguments: Vec<String>,
    #[serde(default)]
    pub allow_local_control_for_development: bool,
}

pub fn state_dir() -> PathBuf {
    if cfg!(windows) {
        PathBuf::from(std::env::var_os("LOCALAPPDATA").unwrap_or_default())
            .join("Leo/StrategyConnector")
    } else if cfg!(target_os = "macos") {
        PathBuf::from(std::env::var_os("HOME").unwrap_or_default())
            .join("Library/Application Support/Leo/StrategyConnector")
    } else {
        PathBuf::from(std::env::var_os("XDG_STATE_HOME").unwrap_or_else(|| {
            PathBuf::from(std::env::var_os("HOME").unwrap_or_default())
                .join(".local/state")
                .into_os_string()
        }))
        .join("leo-strategy-connector")
    }
}

pub fn credential(device: &str) -> Result<keyring::Entry> {
    keyring::Entry::new("com.leo.strategy-connector", device)
        .map_err(|_| anyhow::anyhow!("os_credential_store_unavailable"))
}

fn client() -> Result<Client> {
    Ok(Client::builder()
        .timeout(Duration::from_secs(3))
        .connect_timeout(Duration::from_secs(2))
        .redirect(reqwest::redirect::Policy::none())
        .build()?)
}

#[derive(Clone)]
struct Api {
    client: Client,
    base: String,
    token: String,
}
impl Api {
    fn request(&self, path: &str, body: &Value) -> Result<Value> {
        let key = if path == "/v1/device/events" {
            Some(
                body["events"][0]["id"]
                    .as_str()
                    .context("event_batch_identity_missing")?,
            )
        } else {
            None
        };
        self.request_key(path, body, key)
    }
    fn request_key(&self, path: &str, body: &Value, key: Option<&str>) -> Result<Value> {
        let mut request = self
            .client
            .post(format!("{}{path}", self.base.trim_end_matches('/')))
            .bearer_auth(&self.token)
            .json(body);
        if let Some(key) = key {
            request = request.header("Idempotency-Key", key);
        }
        let response = request
            .send()
            .map_err(|_| anyhow::anyhow!("control_unavailable"))?;
        ensure!(response.status().is_success(), "control_request_rejected");
        let mut raw = Vec::new();
        response
            .take((MAX_RESPONSE + 1) as u64)
            .read_to_end(&mut raw)?;
        ensure!(raw.len() <= MAX_RESPONSE, "control_response_too_large");
        let value: Value = serde_json::from_slice(&raw).context("invalid_control_response")?;
        Ok(value.get("data").cloned().unwrap_or(value))
    }
}

#[allow(clippy::too_many_arguments)] // CLI pairing values stay explicit at this boundary.
pub fn pair(
    api_base: &str,
    name: &str,
    token: &str,
    dir: &Path,
    engine: &Path,
    adapter: &Path,
    args: Vec<String>,
    allow_local: bool,
) -> Result<()> {
    core::verify_endpoint(api_base, allow_local)?;
    ensure!(
        token.len() == 64 && token.bytes().all(|c| c.is_ascii_hexdigit()),
        "invalid_pairing_token"
    );
    ensure!(!name.is_empty() && name.len() <= 80, "invalid_device_name");
    std::fs::create_dir_all(dir)?;
    ensure!(
        !dir.join("config.json").exists(),
        "device_already_paired_use_a_separate_profile"
    );
    let platform = if cfg!(windows) {
        "windows"
    } else if cfg!(target_os = "macos") {
        "macos"
    } else {
        "linux"
    };
    let api = Api {
        client: client()?,
        base: api_base.into(),
        token: String::new(),
    };
    let response = api.request(
        "/v1/device/pair",
        &json!({"pairingToken":token,"name":name,"platform":platform}),
    )?;
    let device = response["deviceId"]
        .as_str()
        .context("missing_device_identity")?;
    let secret = response["deviceToken"]
        .as_str()
        .context("missing_device_credential")?;
    ensure!(
        Uuid::parse_str(device).is_ok() && secret.len() >= 32,
        "invalid_device_credential"
    );
    credential(device)?.set_password(secret).map_err(|_| {
        anyhow::anyhow!("os_credential_write_failed_device_must_be_revoked_and_repaired")
    })?;
    let cfg = Config {
        api_base: api_base.into(),
        device_id: device.into(),
        engine_executable: engine.into(),
        adapter_executable: adapter.into(),
        adapter_arguments: args,
        allow_local_control_for_development: allow_local,
    };
    let mut file = OpenOptions::new()
        .create_new(true)
        .write(true)
        .open(dir.join("config.json"))?;
    file.write_all(serde_json::to_string_pretty(&cfg)?.as_bytes())?;
    file.sync_all()?;
    println!(
        "Paired. Device credential saved in the operating-system credential store. Trading has not started."
    );
    Ok(())
}

pub struct JsonProcess {
    child: Child,
    input: Option<ChildStdin>,
    responses: mpsc::Receiver<Result<Value>>,
}
impl JsonProcess {
    pub fn start(executable: &Path, args: &[String]) -> Result<Self> {
        let mut command = Command::new(executable);
        command
            .args(args)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::null());
        #[cfg(windows)]
        {
            use std::os::windows::process::CommandExt;
            command.creation_flags(0x08000000);
        }
        let mut child = command.spawn().context("sidecar_start_failed")?;
        let input = child.stdin.take().context("sidecar_stdin_missing")?;
        let output = child.stdout.take().context("sidecar_stdout_missing")?;
        let (sender, responses) = mpsc::channel();
        thread::spawn(move || {
            let mut reader = BufReader::new(output);
            loop {
                let mut line = Vec::new();
                let result = reader
                    .by_ref()
                    .take((MAX_RESPONSE + 1) as u64)
                    .read_until(b'\n', &mut line);
                if line.is_empty() {
                    break;
                }
                let parsed = match result {
                    Ok(_) if line.len() <= MAX_RESPONSE => serde_json::from_slice(&line)
                        .map_err(|_| anyhow::anyhow!("invalid_sidecar_response")),
                    _ => Err(anyhow::anyhow!("sidecar_response_too_large")),
                };
                if sender.send(parsed).is_err() {
                    break;
                }
            }
        });
        Ok(Self {
            child,
            input: Some(input),
            responses,
        })
    }
    pub fn call(&mut self, value: &Value) -> Result<Value> {
        self.request(value, false)
    }
    pub fn request(&mut self, value: &Value, close_input: bool) -> Result<Value> {
        let value = self.exchange(value, close_input)?;
        ensure!(value.get("error").is_none(), "sdk_operation_failed");
        Ok(value)
    }
    fn exchange(&mut self, value: &Value, close_input: bool) -> Result<Value> {
        let payload = serde_json::to_vec(value)?;
        ensure!(payload.len() <= MAX_RESPONSE, "sidecar_request_too_large");
        let input = self.input.as_mut().context("sidecar_stdin_closed")?;
        input.write_all(&payload)?;
        input.write_all(b"\n")?;
        input.flush()?;
        if close_input {
            self.input.take();
        }
        match self.responses.recv_timeout(Duration::from_secs(10)) {
            Ok(result) => result,
            Err(_) => {
                let _ = self.child.kill();
                bail!("sidecar_timeout_outcome_may_be_unknown")
            }
        }
    }
}
impl Drop for JsonProcess {
    fn drop(&mut self) {
        let _ = self.child.kill();
        let _ = self.child.wait();
    }
}

fn engine(config: &Config, request: &Value) -> Result<Value> {
    let mut child = JsonProcess::start(&config.engine_executable, &[])?;
    child.request(request, true)
}

struct Shared {
    lease: Option<Lease>,
    accounts: Vec<Account>,
    reconciled: HashSet<String>,
    retirable: HashSet<String>,
    last_snapshot: HashMap<String, chrono::DateTime<Utc>>,
    mandates: HashMap<String, (u64, String)>,
    healthy: bool,
}
impl Shared {
    fn entry_authorized(&self, account: &str) -> bool {
        self.healthy
            && self.reconciled.contains(account)
            && self.fresh(account)
            && self.lease.as_ref().is_some_and(Lease::active)
    }
    fn fresh(&self, account: &str) -> bool {
        self.last_snapshot
            .get(account)
            .is_some_and(|time| (0..=15).contains(&(Utc::now() - *time).num_seconds()))
    }
}

fn control_loop(api: Api, store: Arc<Mutex<Store>>, shared: Arc<Mutex<Shared>>) {
    let instance_id = Uuid::new_v4().to_string();
    loop {
        let started = Instant::now();
        let result = (|| -> Result<()> {
            let accounts = shared.lock().unwrap().accounts.clone();
            let (sequence, acks) = {
                let s = store.lock().unwrap();
                (s.next_poll()?, s.acks()?)
            };
            let value=api.request("/v1/device/poll",&json!({"instanceId":instance_id,"sequence":sequence,"accounts":accounts,"acks":acks}))?;
            let response: PollResponse =
                serde_json::from_value(value).context("invalid_poll_response")?;
            let lease = Lease::accept(&response, started, Utc::now())?;
            let mut state = shared.lock().unwrap();
            let s = store.lock().unwrap();
            s.ack_sent(&acks)?;
            let current: BTreeSet<_> = response.deployments.iter().map(|d| d.id.as_str()).collect();
            for old in s.deployments()? {
                if !current.contains(old.id.as_str()) {
                    s.pause(&old.id, "mandate_unavailable_protection_continues")?;
                }
            }
            state.mandates.clear();
            for deployment in &response.deployments {
                deployment.validate()?;
                validate_config_hash(deployment)?;
                s.deployment(deployment)?;
                if deployment.state == "running"
                    && deployment
                        .lease_expires_at
                        .is_some_and(|at| at > Utc::now())
                {
                    state.mandates.insert(
                        deployment.id.clone(),
                        (
                            deployment.mandate_version,
                            deployment.configuration_hash.clone(),
                        ),
                    );
                }
            }
            for control in response.controls {
                if s.has_ack(&control.control_id)? {
                    continue;
                }
                let d = response
                    .deployments
                    .iter()
                    .find(|d| d.id == control.deployment_id);
                let matched = d.is_some_and(|d| {
                    d.configuration_hash == control.configuration_hash
                        && d.mandate_version == control.mandate_version
                });
                let mut ack = Ack {
                    control_id: control.control_id,
                    status: "rejected".into(),
                    reason: Some("current_mandate_or_reconciliation_required".into()),
                };
                if control.kind == "pause" {
                    s.pause(&control.deployment_id, "user_paused")?;
                    ack.status = "applied".into();
                    ack.reason=Some("new_entry_submissions_paused_existing_orders_can_fill_and_protection_continues".into());
                } else if control.kind == "resume"
                    && matched
                    && d.is_some_and(|d| {
                        state.reconciled.contains(&d.account_id)
                            && state.fresh(&d.account_id)
                            && s.has_unknown(&d.account_id).is_ok_and(|v| !v)
                    })
                {
                    s.resume(&control.deployment_id)?;
                    ack.status = "applied".into();
                    ack.reason = None;
                } else if control.kind == "resume" && matched {
                    continue;
                } else if control.kind == "retire"
                    && matched
                    && d.is_some_and(|d| {
                        state.retirable.contains(&d.account_id) && state.fresh(&d.account_id)
                    })
                {
                    s.pause(&control.deployment_id, "retired")?;
                    ack.status = "applied".into();
                    ack.reason = None;
                }
                s.save_ack(&ack)?;
            }
            state.lease = Some(lease);
            state.healthy = true;
            drop(s);
            drop(state);
            let events = store.lock().unwrap().pending_events()?;
            if !events.is_empty() {
                api.request("/v1/device/events", &json!({"events":events}))?;
                store.lock().unwrap().events_sent(&events)?;
            }
            Ok(())
        })();
        if result.is_err() {
            let mut state = shared.lock().unwrap();
            let was_healthy = state.healthy;
            state.healthy = false;
            state.lease = None;
            let s = store.lock().unwrap();
            if let Ok(deployments) = s.deployments() {
                for d in deployments {
                    let _ = s.pause(&d.id, "control_connection_lost");
                    if was_healthy {
                        let _=s.emit(&d.id,"incident",json!({"code":"control_connection_lost","newEntriesPaused":true,"protectionContinuesWhenBrokerUsable":true}));
                    }
                }
            }
        }
        thread::sleep(core::CONTROL_INTERVAL.saturating_sub(started.elapsed()));
    }
}

fn validate_config_hash(d: &Deployment) -> Result<()> {
    let strategy = d.strategy()?;
    let symbol = d
        .strategy_version
        .get("symbol")
        .and_then(Value::as_str)
        .context("missing_strategy_symbol")?;
    core::validated_symbol(symbol)?;
    ensure!(
        d.strategy_version["parameters"]
            .as_object()
            .is_some_and(|p| p.is_empty()),
        "unsupported_parameter_override"
    );
    // This exact canonical field order is shared with the control API.
    let canonical = format!(
        "{{\"schemaVersion\":\"leo.strategy-version.v1\",\"strategyId\":{},\"symbol\":{},\"parameters\":{{}}}}",
        serde_json::to_string(strategy)?,
        serde_json::to_string(symbol)?
    );
    let expected = format!("{:x}", Sha256::digest(canonical.as_bytes()));
    ensure!(
        d.configuration_hash == expected
            && d.strategy_version["configurationHash"].as_str() == Some(expected.as_str()),
        "configuration_hash_mismatch"
    );
    Ok(())
}

fn submit(
    intent: &OrderIntent,
    sdk: &mut JsonProcess,
    store: &Arc<Mutex<Store>>,
    shared: &Arc<Mutex<Shared>>,
) -> Result<()> {
    // Lock ordering is shared -> store throughout. A persisted claim is in flight;
    // a later pause ACK never claims it has canceled that dispatched work.
    let state = shared.lock().unwrap();
    let authorized = state.entry_authorized(&intent.account_id)
        && state
            .mandates
            .get(&intent.deployment_id)
            .is_some_and(|(version, hash)| {
                *version == intent.mandate_version && *hash == intent.configuration_hash
            });
    let claimed = store.lock().unwrap().claim(intent, authorized)?;
    let deadline = state
        .lease
        .as_ref()
        .map(|lease| Utc::now().timestamp_millis() + lease.remaining_millis() as i64);
    drop(state);
    if !claimed {
        return Ok(());
    }
    let response=sdk.exchange(&json!({"operation":"place","account_id":intent.account_id,"environment":"SIMULATE","intent":intent,"entry_lease_deadline_ms":deadline}),false);
    if let Ok(value) = response {
        if value.get("error").is_some() {
            if value["submission_attempted"] == false {
                store
                    .lock()
                    .unwrap()
                    .reject_before_submission(&intent.client_id)?;
            }
        } else {
            let order: BrokerOrder = serde_json::from_value(value)?;
            store.lock().unwrap().observe(&order, Utc::now())?;
        }
    }
    // Any error after claim stays unknown, including errors that look like rejection.
    store.lock().unwrap().emit(&intent.deployment_id,"order_status",json!({"clientId":intent.client_id,"submissionClaimPersisted":true,"brokerAcknowledgementIsNotFill":true}))?;
    Ok(())
}

fn tick(
    config: &Config,
    sdk: &mut JsonProcess,
    store: &Arc<Mutex<Store>>,
    shared: &Arc<Mutex<Shared>>,
) -> Result<()> {
    let accounts: Vec<Account> =
        serde_json::from_value(sdk.call(&json!({"operation":"accounts"}))?)?;
    for account in &accounts {
        account.validate()?;
    }
    shared.lock().unwrap().accounts = accounts.clone();
    let deployments = store.lock().unwrap().deployments()?;
    for account in accounts {
        let snapshot:Snapshot=serde_json::from_value(sdk.call(&json!({"operation":"snapshot","account_id":account.account_id,"environment":"SIMULATE"}))?)?;
        core::validate_snapshot(&snapshot, &account.account_id, Utc::now())?;
        let reconciled = store.lock().unwrap().reconcile(&snapshot)?;
        let positions_flat = snapshot
            .positions
            .iter()
            .all(|p| money(&p.quantity).is_ok_and(|q| q == Decimal::ZERO));
        let working_orders = snapshot.orders.iter().filter(|o| !o.terminal).count();
        let unknown = store.lock().unwrap().has_unknown(&account.account_id)?;
        {
            let mut state = shared.lock().unwrap();
            state
                .last_snapshot
                .insert(account.account_id.clone(), snapshot.observed_at);
            if reconciled {
                state.reconciled.insert(account.account_id.clone());
            } else {
                state.reconciled.remove(&account.account_id);
            }
            if reconciled && positions_flat && working_orders == 0 && !unknown {
                state.retirable.insert(account.account_id.clone());
            } else {
                state.retirable.remove(&account.account_id);
            }
        }
        {
            let s = store.lock().unwrap();
            let day = Utc::now()
                .with_timezone(&chrono_tz::America::New_York)
                .date_naive()
                .to_string();
            let key = format!("daily_equity:{}:{day}", account.account_id);
            if s.meta(&key)?.is_none() {
                s.set_meta(&key, &snapshot.equity)?;
            }
            let key = format!("peak_equity:{}", account.account_id);
            let peak = money(&s.meta(&key)?.unwrap_or(snapshot.equity.clone()))?
                .max(money(&snapshot.equity)?);
            s.set_meta(&key, &peak.to_string())?;
        }
        // Expired DAY-limit entries are canceled, never blindly replaced. Late fills
        // remain attributable by client ID and update the owned position on refresh.
        let unresolved = store.lock().unwrap().unresolved(&account.account_id)?;
        for order in unresolved {
            if order.side == "BUY"
                && Utc::now() >= entry_deadline(order.created_at)
                && let Some(broker) = snapshot
                    .orders
                    .iter()
                    .find(|o| o.client_id == order.client_id && !o.terminal)
            {
                let _=sdk.call(&json!({"operation":"cancel","account_id":account.account_id,"environment":"SIMULATE","order_id":broker.id}));
            }
        }
        for d in deployments
            .iter()
            .filter(|d| d.account_id == account.account_id)
        {
            if d.state == "retired" {
                continue;
            }
            store.lock().unwrap().emit(&d.id,"reconciliation",json!({"consistent":reconciled,"positionsFlat":positions_flat,"workingOrders":working_orders,"unknownOrders":if unknown{1}else{0},"observedAt":snapshot.observed_at}))?;
            let result = deployment_tick(config, sdk, store, shared, d, &snapshot, reconciled);
            if let Err(error) = result {
                store
                    .lock()
                    .unwrap()
                    .pause(&d.id, "data_or_execution_failure")?;
                store.lock().unwrap().emit(&d.id,"incident",json!({"code":"data_or_execution_failure","protectionStatus":"unavailable","detail":safe_code(&error)}))?;
            }
        }
    }
    Ok(())
}

fn safe_code(error: &anyhow::Error) -> String {
    let text = error.to_string();
    if text.len() < 100 && text.bytes().all(|c| c.is_ascii_lowercase() || c == b'_') {
        text
    } else {
        "operation_unavailable".into()
    }
}

fn deployment_tick(
    config: &Config,
    sdk: &mut JsonProcess,
    store: &Arc<Mutex<Store>>,
    shared: &Arc<Mutex<Shared>>,
    d: &Deployment,
    snapshot: &Snapshot,
    reconciled: bool,
) -> Result<()> {
    deployment_tick_at(config, sdk, store, shared, d, snapshot, reconciled, None)
}

#[allow(clippy::too_many_arguments)] // Explicit clock enables deterministic execution-window regressions.
fn deployment_tick_at(
    config: &Config,
    sdk: &mut JsonProcess,
    store: &Arc<Mutex<Store>>,
    shared: &Arc<Mutex<Shared>>,
    d: &Deployment,
    snapshot: &Snapshot,
    reconciled: bool,
    clock: Option<chrono::DateTime<Utc>>,
) -> Result<()> {
    let symbols = d.selected_symbols();
    ensure!(symbols.len() == 1, "single_symbol_mandate_required");
    let symbol = &symbols[0];
    let mut position = store
        .lock()
        .unwrap()
        .position(&d.id, symbol)?
        .filter(|p| money(&p.quantity).is_ok_and(|v| v > Decimal::ZERO));
    let market = sdk.call(&json!({"operation":"market","symbol":symbol}))?;
    let now = clock.unwrap_or_else(Utc::now);
    let quote: Quote = serde_json::from_value(market["quote"].clone())?;
    let quote_valid = core::validate_quote(&quote, symbol, now);
    let paused = store.lock().unwrap().paused(&d.id)?;
    let orders:Vec<_>=snapshot.orders.iter().filter(|o|!o.terminal).map(|o|json!({"symbol":o.symbol,"side":o.side,"quantity":o.quantity,"filledQuantity":o.filled_quantity,"status":o.status})).collect();
    let positions:Vec<_>=snapshot.positions.iter().map(|p|json!({"symbol":p.symbol,"quantity":p.quantity,"unrealizedPnl":null,"stopPrice":position.as_ref().filter(|owned|owned.symbol==p.symbol).and_then(|p|p.current_stop.clone())})).collect();
    let peak = money(
        &store
            .lock()
            .unwrap()
            .meta(&format!("peak_equity:{}", d.account_id))?
            .unwrap_or(snapshot.equity.clone()),
    )?;
    let drawdown = if peak > Decimal::ZERO {
        ((peak - money(&snapshot.equity)?).max(Decimal::ZERO) / peak * Decimal::from(100))
            .round_dp(4)
            .to_string()
    } else {
        "0".into()
    };
    store.lock().unwrap().emit(&d.id,"heartbeat",json!({"brokerConnectivity":"connected","quoteAgeSeconds":(Utc::now()-quote.observed_at).num_seconds().max(0),"protectionStatus":if quote_valid.is_ok(){"local_software_stop"}else{"unavailable"},"equity":snapshot.equity,"drawdownPercent":drawdown,"positions":positions,"pendingOrders":orders,"reconciled":reconciled,"newEntriesPaused":paused,"mode":d.mode,"individualDealIdsAvailable":false,"fees":"estimated_separately","cashReconciliationTolerance":"0.02","observedAt":snapshot.observed_at}))?;
    // Outside RTH does not invent quotes or execute. Software stops are not active overnight.
    if !quote.market_open {
        return Ok(());
    }
    quote_valid?;
    if let Some(p) = &mut position {
        if p.initial_stop.is_none() {
            let result = engine(
                config,
                &json!({"operation":"stop","strategy":p.strategy,"first_fill_price":p.first_fill_price,"signal_atr":p.signal_atr}),
            )?;
            let stop = result["initial_stop"]
                .as_str()
                .context("missing_engine_stop")?
                .to_string();
            p.initial_stop = Some(stop.clone());
            p.current_stop = Some(stop);
        }
        if money(&quote.bid)? <= money(p.current_stop.as_deref().context("unprotected_position")?)?
        {
            p.stop_latched = true;
        }
        store.lock().unwrap().save_position(p)?;
        if p.stop_latched && reconciled {
            return exit(d, p, "software_stop", sdk, store, shared, snapshot);
        }
    }
    let mut evaluation = market["evaluation"].clone();
    if !evaluation.is_object() {
        store.lock().unwrap().record_decision(&format!("history:{}",now.date_naive()),&d.id,&json!({"action":"hold","reason":"verified_history_or_warmup_unavailable","newEntriesBlocked":true}))?;
        return Ok(());
    }
    if let Some(p) = &mut position {
        update_position_bars(p, &evaluation)?;
        store.lock().unwrap().save_position(p)?;
    }
    evaluation["operation"] = json!("evaluate");
    evaluation["strategy"] = json!(
        position
            .as_ref()
            .map(|p| p.strategy.as_str())
            .unwrap_or(d.strategy()?)
    );
    evaluation["as_of"] = json!(now.to_rfc3339());
    evaluation["pending_entry"] = json!(store.lock().unwrap().pending_for(&d.id, symbol, "BUY")?);
    evaluation["position"] = if let Some(p) = &position {
        json!({"quantity":money(&p.quantity)?.normalize().to_string().parse::<u64>()?,"first_fill_price":p.first_fill_price,"initial_stop":p.initial_stop,"current_stop":p.current_stop,"entry_session":p.entry_session,"highest_close":p.highest_close,"held_sessions":p.held_sessions})
    } else {
        Value::Null
    };
    let result = engine(config, &evaluation)?;
    let decision = result["decision_id"]
        .as_str()
        .context("engine_decision_missing")?;
    store
        .lock()
        .unwrap()
        .record_decision(decision, &d.id, &result)?;
    if let Some(p) = &mut position {
        if let Some(stop) = result["stop_price"].as_str()
            && money(stop)? > money(p.current_stop.as_deref().unwrap_or("0"))?
        {
            p.current_stop = Some(stop.into());
        }
        store.lock().unwrap().save_position(p)?;
        if result["action"] == "exit_long" && reconciled {
            return exit(d, p, decision, sdk, store, shared, snapshot);
        }
        return Ok(());
    }
    if result["action"] != "enter_long" || paused || !reconciled {
        return Ok(());
    }
    let et = now.with_timezone(&chrono_tz::America::New_York);
    use chrono::Timelike;
    if !(et.hour() == 9 && (35..40).contains(&et.minute())) {
        let phase = if et.hour() < 9 || (et.hour() == 9 && et.minute() < 35) {
            "waiting_for_entry_window"
        } else {
            "entry_window_closed_signal_skipped"
        };
        store.lock().unwrap().record_decision(
            &format!("{decision}:{phase}"),
            &d.id,
            &json!({"action":"hold","reason":phase,"window":"09:35-09:40 ET"}),
        )?;
        return Ok(());
    }
    let enabled = shared.lock().unwrap().entry_authorized(&d.account_id);
    ensure!(enabled, "entry_lease_expired");
    if core::validate_entry_spread(&quote).is_err() {
        store.lock().unwrap().record_decision(
            &format!("{decision}:spread"),
            &d.id,
            &json!({"action":"hold","reason":"entry_spread_exceeds_twenty_basis_points"}),
        )?;
        return Ok(());
    }
    ensure!(
        store
            .lock()
            .unwrap()
            .entry_count_on(&d.account_id, et.date_naive())?
            < 3,
        "daily_entry_attempt_limit"
    );
    ensure!(
        !store.lock().unwrap().pending_for(&d.id, symbol, "BUY")?,
        "pending_entry_exists"
    );
    // No shared-underlying allocation until explicit netting is implemented.
    ensure!(
        !store
            .lock()
            .unwrap()
            .positions()?
            .iter()
            .any(|p| p.account_id == d.account_id
                && p.symbol == *symbol
                && money(&p.quantity).is_ok_and(|q| q > Decimal::ZERO)),
        "shared_symbol_exposure_blocked"
    );
    ensure!(
        !snapshot
            .positions
            .iter()
            .any(|p| p.symbol == *symbol && money(&p.quantity).is_ok_and(|q| q != Decimal::ZERO)),
        "existing_broker_symbol_exposure_blocked"
    );
    let gross = snapshot
        .positions
        .iter()
        .try_fold(Decimal::ZERO, |sum, p| {
            Ok::<_, anyhow::Error>(sum + money(&p.market_value)?.abs())
        })?;
    let day = et.date_naive().to_string();
    let day_key = format!("daily_equity:{}:{day}", d.account_id);
    let peak_key = format!("peak_equity:{}", d.account_id);
    let s = store.lock().unwrap();
    let daily = s.meta(&day_key)?.unwrap_or(snapshot.equity.clone());
    s.set_meta(&day_key, &daily)?;
    let peak = s.meta(&peak_key)?.unwrap_or(snapshot.equity.clone());
    let peak = money(&peak)?.max(money(&snapshot.equity)?).to_string();
    s.set_meta(&peak_key, &peak)?;
    let pending = s.pending_commitment(&d.account_id)?.to_string();
    drop(s);
    let atr = result["signal_atr"]
        .as_str()
        .context("missing_signal_atr")?;
    let sized = engine(
        config,
        &json!({"operation":"size","strategy":d.strategy()?,"equity":snapshot.equity,"cash":snapshot.cash,"gross_exposure":gross.to_string(),"pending_commitment":pending,"entry_price":quote.ask,"signal_atr":atr,"daily_start_equity":daily,"peak_equity":peak,"paused":false,"commission_per_order":"0","slippage_bps":10}),
    )?;
    if sized["eligible"] != true {
        store.lock().unwrap().emit(
            &d.id,
            "decision",
            json!({"riskGate":sized,"decisionId":decision}),
        )?;
        return Ok(());
    }
    let quantity = sized["quantity"]
        .as_u64()
        .context("missing_engine_quantity")?;
    let signal_session = evaluation["bars"]
        .as_array()
        .and_then(|bars| bars.last())
        .and_then(|bar| bar["session_date"].as_str())
        .context("signal_session_missing")?;
    ensure!(
        market["entry_session"].as_str() == Some(day.as_str()),
        "signal_not_for_current_session"
    );
    let decision_id = entry_identity(&d.configuration_hash, symbol, signal_session);
    let limit = (money(&quote.ask)? * Decimal::new(10010, 4)).round_dp_with_strategy(
        if money(&quote.ask)? >= Decimal::ONE {
            2
        } else {
            4
        },
        rust_decimal::RoundingStrategy::ToNegativeInfinity,
    );
    let intent = OrderIntent {
        client_id: format!("leo_{}", Uuid::new_v4().simple()),
        deployment_id: d.id.clone(),
        decision_id,
        account_id: d.account_id.clone(),
        symbol: symbol.clone(),
        side: "BUY".into(),
        quantity: quantity.to_string(),
        limit_price: Some(limit.to_string()),
        order_type: "NORMAL".into(),
        strategy: d.strategy()?.into(),
        signal_atr: Some(atr.into()),
        configuration_hash: d.configuration_hash.clone(),
        mandate_version: d.mandate_version,
        reason: "strategy_entry".into(),
        created_at: now,
    };
    if d.mode == "dry_run" {
        store.lock().unwrap().record_decision(&format!("dry:{}",intent.decision_id),&d.id,&json!({"dryRun":true,"proposedOrder":intent,"riskGate":sized,"executionAuthorized":false,"brokerMutation":false}))?;
        return Ok(());
    }
    // Fresh SDK account/quote check is also repeated within adapter.place.
    submit(&intent, sdk, store, shared)
}

fn exit(
    d: &Deployment,
    p: &crate::store::ManagedPosition,
    reason: &str,
    sdk: &mut JsonProcess,
    store: &Arc<Mutex<Store>>,
    shared: &Arc<Mutex<Shared>>,
    snapshot: &Snapshot,
) -> Result<()> {
    if d.mode != "paper"
        || store
            .lock()
            .unwrap()
            .pending_for(&d.id, &p.symbol, "SELL")?
    {
        return Ok(());
    }
    // A cancel response is only a request. Wait for terminal entry evidence before
    // selling owned shares; otherwise a late buy could recreate exposure.
    let entries = store.lock().unwrap().unresolved(&d.account_id)?;
    let entries: Vec<_> = entries
        .iter()
        .filter(|o| o.deployment_id == d.id && o.symbol == p.symbol && o.side == "BUY")
        .collect();
    if !entries.is_empty() {
        for entry in entries {
            if let Some(broker) = snapshot
                .orders
                .iter()
                .find(|o| o.client_id == entry.client_id && !o.terminal)
            {
                let _=sdk.call(&json!({"operation":"cancel","account_id":d.account_id,"environment":"SIMULATE","order_id":broker.id}));
            }
        }
        return Ok(());
    }
    let available = snapshot
        .positions
        .iter()
        .filter(|s| s.symbol == p.symbol)
        .try_fold(Decimal::ZERO, |sum, s| {
            Ok::<_, anyhow::Error>(sum + money(&s.available_quantity)?)
        })?;
    let quantity = available.min(money(&p.quantity)?);
    if quantity <= Decimal::ZERO {
        return Ok(());
    }
    let attempt = store.lock().unwrap().submission_count(&d.id, "SELL")?;
    let intent = OrderIntent {
        client_id: format!("leo_{}", Uuid::new_v4().simple()),
        deployment_id: d.id.clone(),
        decision_id: format!(
            "exit:{}:{}:{}:{attempt}",
            p.entry_session, reason, p.quantity
        ),
        account_id: d.account_id.clone(),
        symbol: p.symbol.clone(),
        side: "SELL".into(),
        quantity: quantity.to_string(),
        limit_price: None,
        order_type: "MARKET".into(),
        strategy: p.strategy.clone(),
        signal_atr: Some(p.signal_atr.clone()),
        configuration_hash: p.configuration_hash.clone(),
        mandate_version: p.mandate_version,
        reason: reason.into(),
        created_at: Utc::now(),
    };
    submit(&intent, sdk, store, shared)
}

fn entry_deadline(created: chrono::DateTime<Utc>) -> chrono::DateTime<Utc> {
    use chrono::Timelike;
    created
        .with_timezone(&chrono_tz::America::New_York)
        .with_hour(9)
        .unwrap()
        .with_minute(40)
        .unwrap()
        .with_second(0)
        .unwrap()
        .with_nanosecond(0)
        .unwrap()
        .with_timezone(&Utc)
}
fn entry_identity(hash: &str, symbol: &str, session: &str) -> String {
    format!(
        "entry:{:x}",
        Sha256::digest(format!("{hash}|{symbol}|{session}"))
    )
}
fn update_position_bars(p: &mut crate::store::ManagedPosition, evaluation: &Value) -> Result<()> {
    let bars = evaluation["bars"]
        .as_array()
        .context("daily_bars_missing")?;
    p.held_sessions = bars
        .iter()
        .filter(|b| {
            b["session_date"]
                .as_str()
                .is_some_and(|date| date >= p.entry_session.as_str())
        })
        .count() as u64;
    for b in bars.iter().filter(|b| {
        b["session_date"]
            .as_str()
            .is_some_and(|date| date >= p.entry_session.as_str())
    }) {
        let close = b["close"].as_str().context("close_missing")?;
        if money(close)? > money(&p.highest_close)? {
            p.highest_close = close.into();
        }
    }
    Ok(())
}

pub fn run(dir: &Path, once: bool) -> Result<()> {
    let config: Config = serde_json::from_reader(File::open(dir.join("config.json"))?)?;
    core::verify_endpoint(&config.api_base, config.allow_local_control_for_development)?;
    let lock = OpenOptions::new()
        .create(true)
        .truncate(false)
        .read(true)
        .write(true)
        .open(dir.join("connector.lock"))?;
    lock.try_lock_exclusive()
        .context("connector_already_running")?;
    let token = credential(&config.device_id)?
        .get_password()
        .map_err(|_| anyhow::anyhow!("os_credential_read_failed"))?;
    let api = Api {
        client: client()?,
        base: config.api_base.clone(),
        token: format!("{}.{}", config.device_id, token),
    };
    let store = Arc::new(Mutex::new(Store::open(&dir.join("journal.sqlite3"))?));
    let shared = Arc::new(Mutex::new(Shared {
        lease: None,
        accounts: vec![],
        reconciled: HashSet::new(),
        retirable: HashSet::new(),
        last_snapshot: HashMap::new(),
        mandates: HashMap::new(),
        healthy: false,
    }));
    {
        let s = store.clone();
        let shared = shared.clone();
        thread::spawn(move || control_loop(api, s, shared));
    }
    loop {
        let mut sdk = JsonProcess::start(&config.adapter_executable, &config.adapter_arguments)?;
        loop {
            if tick(&config, &mut sdk, &store, &shared).is_err() {
                shared.lock().unwrap().reconciled.clear();
                let deployments = store.lock().unwrap().deployments()?;
                for d in deployments {
                    let s = store.lock().unwrap();
                    s.pause(&d.id, "broker_unavailable")?;
                    s.emit(&d.id,"incident",json!({"code":"broker_unavailable","newEntriesPaused":true,"protectionStatus":"unavailable"}))?;
                    s.emit(&d.id,"heartbeat",json!({"brokerConnectivity":"disconnected","quoteAgeSeconds":null,"protectionStatus":"unavailable","equity":null,"drawdownPercent":null,"preserveLastVerifiedValues":true}))?;
                }
                if once {
                    return Err(anyhow::anyhow!("broker_unavailable"));
                }
                break;
            }
            if once {
                return Ok(());
            }
            thread::sleep(core::CONTROL_INTERVAL);
        }
        thread::sleep(core::CONTROL_INTERVAL);
    }
}

pub fn upload_report(dir: &Path, run_id: &str, path: &Path) -> Result<()> {
    ensure!(
        Uuid::parse_str(run_id).is_ok(),
        "invalid_research_run_identity"
    );
    let config: Config = serde_json::from_reader(File::open(dir.join("config.json"))?)?;
    core::verify_endpoint(&config.api_base, config.allow_local_control_for_development)?;
    let mut bytes = Vec::new();
    File::open(path)?
        .take((MAX_RESPONSE + 1) as u64)
        .read_to_end(&mut bytes)?;
    ensure!(bytes.len() <= MAX_RESPONSE, "report_too_large");
    let report: Value = serde_json::from_slice(&bytes)?;
    ensure!(
        report["schema_version"] == "leo-strategy-research.v1",
        "unsupported_research_report"
    );
    let digest = format!("{:x}", Sha256::digest(&bytes));
    // Separate outbox: uploading research must never pause a running connector.
    let journal = Store::open(&dir.join("research-upload.sqlite3"))?;
    let meta_key = format!("report:{run_id}:{digest}");
    let key = journal
        .meta(&meta_key)?
        .unwrap_or_else(|| Uuid::new_v4().to_string());
    journal.set_meta(&meta_key, &key)?;
    let secret = credential(&config.device_id)?
        .get_password()
        .map_err(|_| anyhow::anyhow!("os_credential_read_failed"))?;
    let api = Api {
        client: client()?,
        base: config.api_base,
        token: format!("{}.{}", config.device_id, secret),
    };
    api.request_key(
        &format!("/v1/device/research-runs/{run_id}/report"),
        &json!({"report":report}),
        Some(&key),
    )?;
    println!("Research report uploaded. This does not authorize or promote a strategy.");
    Ok(())
}

pub fn resolve_flat_account(dir: &Path, account_id: &str) -> Result<()> {
    let config: Config = serde_json::from_reader(File::open(dir.join("config.json"))?)?;
    let lock = OpenOptions::new()
        .create(true)
        .truncate(false)
        .read(true)
        .write(true)
        .open(dir.join("connector.lock"))?;
    lock.try_lock_exclusive()
        .context("stop_connector_before_manual_resolution")?;
    let mut store = Store::open(&dir.join("journal.sqlite3"))?;
    ensure!(
        store
            .deployments()?
            .iter()
            .any(|d| d.account_id == account_id),
        "known_paper_account_required"
    );
    let mut sdk = JsonProcess::start(&config.adapter_executable, &config.adapter_arguments)?;
    let snapshot: Snapshot = serde_json::from_value(sdk.call(
        &json!({"operation":"snapshot","account_id":account_id,"environment":"SIMULATE"}),
    )?)?;
    core::validate_snapshot(&snapshot, account_id, Utc::now())?;
    let _ = store.reconcile(&snapshot)?;
    store.resolve_verified_flat(&snapshot)?;
    println!(
        "Verified flat paper account resolved. Prior evidence is preserved; restart the connector and explicitly resume in the web app."
    );
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    fn deployment() -> Deployment {
        let canonical = "{\"schemaVersion\":\"leo.strategy-version.v1\",\"strategyId\":\"MR-v1\",\"symbol\":\"SPY\",\"parameters\":{}}";
        let hash = format!("{:x}", Sha256::digest(canonical));
        serde_json::from_value(json!({"id":"dep","mandateVersion":1,"configurationHash":hash,"strategyVersion":{"strategyId":"MR-v1","symbol":"SPY","parameters":{},"configurationHash":hash},"accountId":"123","mode":"paper","state":"paused","leaseExpiresAt":null})).unwrap()
    }
    fn shared() -> Arc<Mutex<Shared>> {
        Arc::new(Mutex::new(Shared {
            lease: None,
            accounts: vec![],
            reconciled: HashSet::new(),
            retirable: HashSet::new(),
            last_snapshot: HashMap::new(),
            mandates: HashMap::new(),
            healthy: false,
        }))
    }
    fn peer(dir: &Path, mode: &str) -> (JsonProcess, PathBuf) {
        let python = std::env::var_os("LEO_TEST_PYTHON")
            .map(PathBuf::from)
            .unwrap_or_else(|| PathBuf::from(if cfg!(windows) { "python" } else { "python3" }));
        let log = dir.join("peer.jsonl");
        let script = Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/fake_peer.py");
        let process = JsonProcess::start(
            &python,
            &[
                script.to_string_lossy().into(),
                mode.into(),
                log.to_string_lossy().into(),
            ],
        )
        .unwrap();
        (process, log)
    }
    fn config() -> Config {
        Config {
            api_base: "https://example.test".into(),
            device_id: "fixture".into(),
            engine_executable: "missing-engine-not-needed-for-persisted-stop".into(),
            adapter_executable: "fixture".into(),
            adapter_arguments: vec![],
            allow_local_control_for_development: false,
        }
    }
    fn setup() -> (Arc<Mutex<Store>>, Deployment, OrderIntent, Snapshot) {
        let mut store = Store::open(Path::new(":memory:")).unwrap();
        let d = deployment();
        store.deployment(&d).unwrap();
        store.resume(&d.id).unwrap();
        let intent = OrderIntent {
            client_id: "leo_test_entry".into(),
            deployment_id: d.id.clone(),
            decision_id: "entry:original-session".into(),
            account_id: d.account_id.clone(),
            symbol: "SPY".into(),
            side: "BUY".into(),
            quantity: "2".into(),
            limit_price: Some("100".into()),
            order_type: "NORMAL".into(),
            strategy: "MR-v1".into(),
            signal_atr: Some("2".into()),
            configuration_hash: d.configuration_hash.clone(),
            mandate_version: 1,
            reason: "entry".into(),
            created_at: Utc::now(),
        };
        store.claim(&intent, true).unwrap();
        let entry = BrokerOrder {
            id: "entry-broker".into(),
            client_id: intent.client_id.clone(),
            symbol: "SPY".into(),
            side: "BUY".into(),
            quantity: "2".into(),
            filled_quantity: "1".into(),
            average_fill_price: Some("100".into()),
            status: "FILLED_PART".into(),
            terminal: false,
        };
        store.observe(&entry, Utc::now()).unwrap();
        let mut p = store.position("dep", "SPY").unwrap().unwrap();
        p.initial_stop = Some("96".into());
        p.current_stop = Some("96".into());
        store.save_position(&p).unwrap();
        store.pause("dep", "user_pause").unwrap();
        let snap = Snapshot {
            account_id: "123".into(),
            environment: "SIMULATE".into(),
            observed_at: Utc::now(),
            cash: "9900".into(),
            equity: "9990".into(),
            positions: vec![Position {
                symbol: "SPY".into(),
                quantity: "1".into(),
                available_quantity: "1".into(),
                market_value: "90".into(),
            }],
            orders: vec![entry],
            history_complete: false,
        };
        (Arc::new(Mutex::new(store)), d, intent, snap)
    }
    fn calls(log: &Path) -> Vec<Value> {
        std::fs::read_to_string(log)
            .unwrap_or_default()
            .lines()
            .map(|line| serde_json::from_str(line).unwrap())
            .collect()
    }

    #[test]
    fn stop_waits_for_cancel_terminal_then_exits_after_pause_and_lease_loss() {
        let dir = tempfile::tempdir().unwrap();
        let (mut sdk, log) = peer(dir.path(), "fill");
        let (store, d, _entry, mut snap) = setup();
        let shared = shared();
        deployment_tick(&config(), &mut sdk, &store, &shared, &d, &snap, true).unwrap();
        assert!(
            store
                .lock()
                .unwrap()
                .position("dep", "SPY")
                .unwrap()
                .unwrap()
                .stop_latched
        );
        assert_eq!(
            calls(&log)
                .iter()
                .filter(|c| c["operation"] == "cancel")
                .count(),
            1
        );
        assert_eq!(
            calls(&log)
                .iter()
                .filter(|c| c["operation"] == "place")
                .count(),
            0
        );
        // Cancel/fill race: the second share filled before cancellation completed.
        snap.orders[0].filled_quantity = "2".into();
        snap.orders[0].average_fill_price = Some("99".into());
        snap.orders[0].terminal = true;
        snap.orders[0].status = "FILLED_ALL".into();
        store
            .lock()
            .unwrap()
            .observe(&snap.orders[0], Utc::now())
            .unwrap();
        snap.positions[0].quantity = "2".into();
        snap.positions[0].available_quantity = "2".into();
        deployment_tick(&config(), &mut sdk, &store, &shared, &d, &snap, true).unwrap();
        let calls = calls(&log);
        let exit = calls.iter().find(|c| c["operation"] == "place").unwrap();
        assert_eq!(exit["intent"]["side"], "SELL");
        assert_eq!(exit["intent"]["quantity"], "2");
        assert_eq!(exit["environment"], "SIMULATE");
        assert_eq!(
            store
                .lock()
                .unwrap()
                .position("dep", "SPY")
                .unwrap()
                .unwrap()
                .quantity,
            "0"
        );
    }
    #[test]
    fn ambiguous_exit_is_never_resubmitted() {
        let dir = tempfile::tempdir().unwrap();
        let (mut sdk, log) = peer(dir.path(), "unknown");
        let (store, d, _, mut snap) = setup();
        snap.orders[0].terminal = true;
        snap.orders[0].status = "CANCELLED_PART".into();
        store
            .lock()
            .unwrap()
            .observe(&snap.orders[0], Utc::now())
            .unwrap();
        let shared = shared();
        deployment_tick(&config(), &mut sdk, &store, &shared, &d, &snap, true).unwrap();
        assert!(store.lock().unwrap().has_unknown("123").unwrap());
        deployment_tick(&config(), &mut sdk, &store, &shared, &d, &snap, false).unwrap();
        assert_eq!(
            calls(&log)
                .iter()
                .filter(|c| c["operation"] == "place")
                .count(),
            1
        );
    }
    #[test]
    fn expired_entry_lease_never_reaches_sdk() {
        let dir = tempfile::tempdir().unwrap();
        let (mut sdk, log) = peer(dir.path(), "fill");
        let (store, _, mut intent, _) = setup();
        intent.decision_id = "new-session".into();
        intent.client_id = "leo_new".into();
        assert!(submit(&intent, &mut sdk, &store, &shared()).is_err());
        assert!(calls(&log).is_empty());
    }
    #[test]
    fn configuration_hash_and_session_identity_are_immutable() {
        let d = deployment();
        validate_config_hash(&d).unwrap();
        let mut changed = d.clone();
        changed.strategy_version["symbol"] = json!("AAPL");
        assert!(validate_config_hash(&changed).is_err());
        assert_ne!(
            entry_identity(&d.configuration_hash, "SPY", "2026-09-04"),
            entry_identity(&d.configuration_hash, "SPY", "2026-09-08")
        );
        let created = chrono::DateTime::parse_from_rfc3339("2026-09-08T13:36:30Z")
            .unwrap()
            .with_timezone(&Utc);
        assert_eq!(
            entry_deadline(created).to_rfc3339(),
            "2026-09-08T13:40:00+00:00"
        );
    }
    #[test]
    fn holding_session_count_includes_entry_before_engine_evaluation() {
        let (store, _, _, _) = setup();
        let mut p = store
            .lock()
            .unwrap()
            .position("dep", "SPY")
            .unwrap()
            .unwrap();
        p.entry_session = "2026-09-01".into();
        update_position_bars(&mut p,&json!({"bars":[{"session_date":"2026-08-31","close":"110"},{"session_date":"2026-09-01","close":"101"},{"session_date":"2026-09-02","close":"102"}]})).unwrap();
        assert_eq!(p.held_sessions, 2);
        assert_eq!(p.highest_close, "102");
    }

    #[test]
    fn actual_engine_consumes_current_snapshot_and_decimal_share_position() {
        let path = std::env::var_os("LEO_TEST_ENGINE")
            .map(PathBuf::from)
            .unwrap_or_else(|| {
                Path::new(env!("CARGO_MANIFEST_DIR"))
                    .join("../../quant_engine_rs/target/debug")
                    .join(if cfg!(windows) {
                        "strategy-lab.exe"
                    } else {
                        "strategy-lab"
                    })
            });
        assert!(
            path.is_file(),
            "Build strategy-lab before connector integration tests or set LEO_TEST_ENGINE"
        );
        let dir = tempfile::tempdir().unwrap();
        let (mut sdk, log) = peer(dir.path(), "evaluate");
        let (store, d, _, mut snap) = setup();
        snap.orders[0].terminal = true;
        snap.orders[0].status = "CANCELLED_PART".into();
        store
            .lock()
            .unwrap()
            .observe(&snap.orders[0], Utc::now())
            .unwrap();
        let mut p = store
            .lock()
            .unwrap()
            .position("dep", "SPY")
            .unwrap()
            .unwrap();
        p.quantity = "1.000000".into();
        store.lock().unwrap().save_position(&p).unwrap();
        let mut cfg = config();
        cfg.engine_executable = path;
        deployment_tick(&cfg, &mut sdk, &store, &shared(), &d, &snap, true).unwrap();
        let events = store.lock().unwrap().pending_events().unwrap();
        let decision = events
            .iter()
            .find(|e| e.kind == "decision")
            .expect("real engine decision persisted");
        assert_eq!(
            decision.payload["history_mode"],
            "current_observed_snapshot"
        );
        assert_eq!(decision.payload["action"], "hold");
        assert!(!calls(&log).iter().any(|c| c["operation"] == "place"));
    }

    #[test]
    fn prewindow_signal_does_not_pause_and_dry_run_sizes_without_broker_mutation() {
        for mode in ["paper", "dry_run"] {
            let dir = tempfile::tempdir().unwrap();
            let mut d = deployment();
            d.mode = mode.into();
            d.state = "running".into();
            let s = Store::open(Path::new(":memory:")).unwrap();
            s.deployment(&d).unwrap();
            s.resume(&d.id).unwrap();
            let store = Arc::new(Mutex::new(s));
            let shared = shared();
            let current = Utc::now();
            let response = PollResponse {
                server_time: current,
                lease_expires_at: current + chrono::Duration::seconds(15),
                lease_generation: 1,
                deployments: vec![],
                controls: vec![],
            };
            {
                let mut state = shared.lock().unwrap();
                state.healthy = true;
                state.reconciled.insert(d.account_id.clone());
                state.last_snapshot.insert(d.account_id.clone(), current);
                state.mandates.insert(
                    d.id.clone(),
                    (d.mandate_version, d.configuration_hash.clone()),
                );
                state.lease = Some(Lease::accept(&response, Instant::now(), current).unwrap());
            }
            let snap = Snapshot {
                account_id: d.account_id.clone(),
                environment: "SIMULATE".into(),
                observed_at: current,
                cash: "10000".into(),
                equity: "10000".into(),
                positions: vec![],
                orders: vec![],
                history_complete: false,
            };
            let mut cfg = config();
            cfg.engine_executable = std::env::var_os("LEO_TEST_ENGINE")
                .map(PathBuf::from)
                .unwrap_or_else(|| {
                    Path::new(env!("CARGO_MANIFEST_DIR"))
                        .join("../../quant_engine_rs/target/debug")
                        .join(if cfg!(windows) {
                            "strategy-lab.exe"
                        } else {
                            "strategy-lab"
                        })
                });
            let before = chrono::DateTime::parse_from_rfc3339("2026-09-08T13:30:00Z")
                .unwrap()
                .with_timezone(&Utc);
            let (mut sdk, log) = peer(dir.path(), "entry@2026-09-08T13:30:00+00:00");
            deployment_tick_at(
                &cfg,
                &mut sdk,
                &store,
                &shared,
                &d,
                &snap,
                true,
                Some(before),
            )
            .unwrap();
            assert!(!store.lock().unwrap().paused("dep").unwrap());
            assert!(!calls(&log).iter().any(|c| c["operation"] == "place"));
            drop(sdk);
            let inside = before + chrono::Duration::minutes(5);
            let (mut sdk, log) = peer(dir.path(), "entry@2026-09-08T13:35:00+00:00");
            deployment_tick_at(
                &cfg,
                &mut sdk,
                &store,
                &shared,
                &d,
                &snap,
                true,
                Some(inside),
            )
            .unwrap();
            let mutations = calls(&log)
                .iter()
                .filter(|c| c["operation"] == "place" || c["operation"] == "cancel")
                .count();
            if mode == "paper" {
                assert_eq!(mutations, 1, "09:30 signal must remain eligible at09:35");
                assert_eq!(
                    store
                        .lock()
                        .unwrap()
                        .submission_count("dep", "BUY")
                        .unwrap(),
                    1
                );
            } else {
                assert_eq!(mutations, 0);
                assert_eq!(
                    store
                        .lock()
                        .unwrap()
                        .submission_count("dep", "BUY")
                        .unwrap(),
                    0
                );
                let events = store.lock().unwrap().pending_events().unwrap();
                let proposal = events
                    .iter()
                    .find(|e| e.payload["dryRun"] == true)
                    .expect("sized dry proposal");
                assert!(
                    money(
                        proposal.payload["proposedOrder"]["quantity"]
                            .as_str()
                            .unwrap()
                    )
                    .unwrap()
                        > Decimal::ZERO
                );
            }
        }
    }
}
