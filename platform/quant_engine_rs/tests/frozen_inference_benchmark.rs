use std::{
    collections::BTreeSet,
    env,
    path::{Path, PathBuf},
    time::{Duration, Instant},
};

use anyhow::{Context, Result};
use axio_quant_engine::{
    AppConfig,
    data::{
        LicensedFileImporter, capability::DataCapabilityReport, csv_import::MarketBarCsvImporter,
        manifest,
    },
    engine::features,
    frozen_universe::{canonical_model_symbol, load_frozen_universe},
    predictor::{self, FrozenInferenceCache},
};
use chrono::Utc;

struct CurrentDirectoryGuard(PathBuf);

impl CurrentDirectoryGuard {
    fn enter(path: &Path) -> Result<Self> {
        let previous = env::current_dir()?;
        env::set_current_dir(path)?;
        Ok(Self(previous))
    }
}

impl Drop for CurrentDirectoryGuard {
    fn drop(&mut self) {
        let _ = env::set_current_dir(&self.0);
    }
}

fn percentile(sorted: &[Duration], percentile: usize) -> Duration {
    let index = (sorted.len().saturating_sub(1) * percentile).div_ceil(100);
    sorted[index.min(sorted.len().saturating_sub(1))]
}

fn required_explicit_path(root: &Path, variable: &str) -> Result<PathBuf> {
    let configured = PathBuf::from(env::var(variable).with_context(|| {
        format!("{variable} must explicitly identify benchmark input; no release input is inferred")
    })?);
    let resolved = if configured.is_absolute() {
        configured
    } else {
        root.join(configured)
    };
    resolved
        .canonicalize()
        .with_context(|| format!("{variable} path {} is unavailable", resolved.display()))
}

/// Opt-in, real-artifact performance receipt. This is ignored in ordinary CI
/// because it loads explicitly named licensed normalized history and frozen
/// artifacts. It is performance evidence only, never release acceptance.
///
/// Run in release mode:
/// `cargo test --release --test frozen_inference_benchmark -- --ignored --nocapture`
#[test]
#[ignore = "requires an explicit local licensed-data root and release-mode timing"]
fn report_real_nine_target_frozen_inference_latency() -> Result<()> {
    let root = PathBuf::from(
        env::var("AXIO7_FROZEN_BENCH_ROOT")
            .context("AXIO7_FROZEN_BENCH_ROOT must name the quant_engine_rs directory")?,
    )
    .canonicalize()?;
    let _cwd = CurrentDirectoryGuard::enter(&root)?;
    let evidence_label = env::var("AXIO7_FROZEN_BENCH_EVIDENCE_LABEL")
        .context("AXIO7_FROZEN_BENCH_EVIDENCE_LABEL is required")?;
    anyhow::ensure!(
        !evidence_label.trim().is_empty(),
        "AXIO7_FROZEN_BENCH_EVIDENCE_LABEL must not be empty"
    );
    let bars_path = required_explicit_path(&root, "AXIO7_FROZEN_BENCH_BARS_PATH")?;
    let registry_path = required_explicit_path(&root, "AXIO7_FROZEN_BENCH_REGISTRY_PATH")?;
    let expected_bars_bytes = env::var("AXIO7_FROZEN_BENCH_EXPECTED_BARS_BYTES")
        .context("AXIO7_FROZEN_BENCH_EXPECTED_BARS_BYTES is required")?
        .parse::<u64>()
        .context("AXIO7_FROZEN_BENCH_EXPECTED_BARS_BYTES must be an unsigned integer")?;
    let bars_bytes = std::fs::metadata(&bars_path)?.len();
    anyhow::ensure!(
        bars_bytes == expected_bars_bytes,
        "explicit benchmark bars byte count mismatch: expected={expected_bars_bytes} actual={bars_bytes}"
    );
    let bars_sha256 = manifest::sha256_file(&bars_path)?;
    let config = AppConfig::load(root.join("configs/production.yaml"))?;
    let capability_receipt: serde_json::Value = serde_json::from_slice(&std::fs::read(
        root.join("data/quality/data_capability_latest.json"),
    )?)?;
    let mut capability: DataCapabilityReport = serde_json::from_value(
        capability_receipt
            .get("data")
            .cloned()
            .unwrap_or(capability_receipt),
    )?;
    let capability_reported_sha256 = capability
        .normalized_file_sha256
        .clone()
        .unwrap_or_else(|| "MISSING".into());
    let bars = MarketBarCsvImporter.import(&bars_path)?.records;
    let requested = config
        .live
        .forecast_symbols
        .iter()
        .map(|symbol| canonical_model_symbol(symbol))
        .collect::<Result<BTreeSet<_>>>()?;
    anyhow::ensure!(
        requested.len() == 9,
        "benchmark requires the exact configured nine-symbol universe"
    );
    let universe = load_frozen_universe(&registry_path, &requested)?;
    anyhow::ensure!(
        universe.failures().is_empty(),
        "benchmark universe is incomplete: {:?}",
        universe.failures()
    );
    for target in &requested {
        let artifact = universe
            .artifact(target)
            .with_context(|| format!("missing frozen artifact for {target}"))?;
        anyhow::ensure!(
            artifact.training_dataset_hash == bars_sha256,
            "{target} frozen artifact is not bound to the independently hashed explicit bars"
        );
    }
    let capability_hash_rebound =
        capability.normalized_file_sha256.as_deref() != Some(bars_sha256.as_str());
    // This ignored performance-only test may consume an old capability report
    // whose cached file hash predates the exact artifact-bound bars. Rebinding
    // happens only in this process after every requested artifact has matched
    // an independent hash of the explicit input. No file is written and no
    // production binary exposes this path.
    capability.normalized_file_sha256 = Some(bars_sha256.clone());

    let mut inputs = Vec::new();
    for target in &requested {
        let mut research = config.research.clone();
        research.target = target.clone();
        let states = features::build_states_for_observed_feature_contract(
            &bars,
            target,
            &research,
            &config.live.context_observation_policy,
            &config.live.cross_asset_feature_schema,
        )?;
        let artifact = universe
            .artifact(target)
            .with_context(|| format!("missing frozen artifact for {target}"))?;
        inputs.push((target.clone(), research, states, artifact));
    }

    let samples = env::var("AXIO7_FROZEN_BENCH_SAMPLES")
        .ok()
        .and_then(|value| value.parse::<usize>().ok())
        .unwrap_or(3)
        .max(1);
    let worker_limit = env::var("AXIO7_FROZEN_BENCH_WORKERS")
        .ok()
        .and_then(|value| value.parse::<usize>().ok())
        .unwrap_or(4)
        .clamp(1, inputs.len().min(4));
    let mut target_samples = inputs
        .iter()
        .map(|(target, _, _, _)| (target.clone(), Vec::new()))
        .collect::<std::collections::BTreeMap<_, _>>();
    let mut batch_samples = Vec::new();

    for _ in 0..samples {
        let batch_started = Instant::now();
        let inference_as_of = Utc::now();
        let chunk_size = inputs.len().div_ceil(worker_limit);
        let rows = std::thread::scope(|scope| {
            let mut handles = Vec::new();
            for chunk in inputs.chunks(chunk_size) {
                let os = &config.os;
                let capability = &capability;
                handles.push(scope.spawn(move || {
                    chunk
                        .iter()
                        .map(|(target, research, states, artifact)| {
                            let started = Instant::now();
                            let mut cache = FrozenInferenceCache::default();
                            let bundle = predictor::forecast_with_frozen_artifact_cached(
                                states,
                                research,
                                os,
                                capability,
                                inference_as_of,
                                artifact,
                                &mut cache,
                            )?;
                            let actual_horizons = bundle
                                .prediction_layer
                                .iter()
                                .map(|contract| contract.horizon_minutes)
                                .collect::<BTreeSet<_>>();
                            anyhow::ensure!(
                                actual_horizons == BTreeSet::from([5, 15, 30, 60])
                                    && bundle.unavailable_horizons.is_empty(),
                                "{target} did not produce all four horizons"
                            );
                            anyhow::ensure!(
                                !bundle.research_only_policy.personalization_used
                                    && !bundle.research_only_policy.user_portfolio_inputs_used
                                    && !bundle.research_only_policy.investment_advice
                                    && !bundle.research_only_policy.execution_instruction
                                    && bundle.prediction_layer.iter().all(|contract| {
                                        contract.decision.action == "NO_TRADE"
                                            && !contract.decision.eligible
                                    }),
                                "{target} violated the research-only execution-disabled contract"
                            );
                            anyhow::ensure!(
                                cache.rebuild_count() == 1,
                                "{target} rebuilt a frozen request cache more than once"
                            );
                            Ok::<_, anyhow::Error>((target.clone(), started.elapsed()))
                        })
                        .collect::<Result<Vec<_>>>()
                }));
            }
            let chunks = handles
                .into_iter()
                .map(|handle| handle.join().expect("benchmark worker panicked"))
                .collect::<Result<Vec<_>>>()?;
            Ok::<_, anyhow::Error>(chunks.into_iter().flatten().collect::<Vec<_>>())
        })?;
        batch_samples.push(batch_started.elapsed());
        for (target, elapsed) in rows {
            target_samples
                .get_mut(&target)
                .expect("configured target sample bucket")
                .push(elapsed);
        }
    }

    println!(
        "FROZEN_INFERENCE_BENCH_INPUT status=PERFORMANCE_ONLY_NOT_RELEASE_ACCEPTANCE evidence_label={} source={} bars_bytes={} bars_sha256={} capability_reported_sha256={} capability_hash_rebound={} targets={} horizons=5,15,30,60 registry={}",
        evidence_label,
        capability.source,
        bars_bytes,
        bars_sha256,
        capability_reported_sha256,
        capability_hash_rebound,
        inputs.len(),
        registry_path.display()
    );
    for (target, mut rows) in target_samples {
        rows.sort();
        println!(
            "FROZEN_INFERENCE_BENCH target={target} samples={} p50_ms={} max_ms={}",
            rows.len(),
            percentile(&rows, 50).as_millis(),
            rows.last().expect("nonempty target timings").as_millis()
        );
    }
    batch_samples.sort();
    println!(
        "FROZEN_INFERENCE_BENCH batch_targets={} workers={} samples={} p50_ms={} max_ms={} sla_ms={}",
        inputs.len(),
        worker_limit,
        batch_samples.len(),
        percentile(&batch_samples, 50).as_millis(),
        batch_samples
            .last()
            .expect("nonempty batch timings")
            .as_millis(),
        config.live.prediction_sla_ms
    );
    let maximum_batch_ms = batch_samples
        .last()
        .expect("nonempty batch timings")
        .as_millis();
    anyhow::ensure!(
        config.live.prediction_sla_ms >= 0
            && maximum_batch_ms <= config.live.prediction_sla_ms as u128,
        "nine-target frozen inference exceeded the configured SLA: max_ms={maximum_batch_ms} sla_ms={}",
        config.live.prediction_sla_ms
    );
    Ok(())
}
