use std::path::PathBuf;

use anyhow::Result;
use axio_quant_engine::{
    AppConfig, api,
    data::{databento_inference, databento_live, massive_live},
    live,
};
use clap::Parser;
use tracing_subscriber::EnvFilter;

#[derive(Debug, Parser)]
#[command(name = "quantd", about = "AXIO7 Rust intraday quant service")]
struct Args {
    #[arg(long, default_value = "configs/production.yaml")]
    config: PathBuf,
    #[arg(long)]
    host: Option<String>,
    #[arg(long)]
    port: Option<u16>,
}

#[tokio::main]
async fn main() -> Result<()> {
    axio_quant_engine::install_tls_crypto_provider();
    let _ = dotenvy::from_filename("../.env.local");
    let _ = dotenvy::dotenv();
    tracing_subscriber::fmt()
        .with_env_filter(
            EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| EnvFilter::new("axio_quant_engine=info,tower_http=info")),
        )
        .init();
    let args = Args::parse();
    let mut config = AppConfig::load(args.config)?;
    if let Some(host) = args.host {
        config.server.host = host;
    }
    if let Some(port) = args.port {
        config.server.port = port;
    }
    config.validate()?;
    let mut live_supervisor = None;
    let mut inference_supervisor = None;
    if config.live.enabled {
        let root = config
            .data
            .raw_root
            .parent()
            .unwrap_or(std::path::Path::new("data"));
        std::fs::create_dir_all(root.join("live"))?;
        if config.live.provider == "massive" {
            let path = root.join("live/massive_readiness.json");
            let massive_config = config.data.massive.clone();
            let live_config = config.live.clone();
            tokio::spawn(async move {
                match massive_live::check_realtime_entitlements(&massive_config, &live_config).await
                {
                    Ok(readiness) => match serde_json::to_vec_pretty(&readiness) {
                        Ok(bytes) => {
                            if let Err(error) = std::fs::write(&path, bytes) {
                                tracing::error!(%error, "write Massive readiness artifact");
                            } else {
                                tracing::info!(
                                    production_ready = readiness.production_ready,
                                    blockers = readiness.blockers.len(),
                                    "Massive SIP/OPRA readiness check"
                                );
                            }
                        }
                        Err(error) => {
                            tracing::error!(%error, "serialize Massive readiness artifact");
                        }
                    },
                    Err(error) => {
                        tracing::error!(%error, "Massive SIP/OPRA readiness check failed");
                    }
                }
            });
        } else if config.live.provider == "databento" {
            let status_path = root.join("live/databento_stream_status.json");
            let bars_path = root.join("live/databento_stock_bars.jsonl");
            let database_path = root.join("market/databento_market_data.sqlite3");
            let (inference_sender, inference_receiver) = tokio::sync::mpsc::channel(4096);
            let data_config = config.data.clone();
            let live_config = config.live.clone();
            let inference_config = config.clone();
            let inference_root = root.to_path_buf();
            inference_supervisor = Some(tokio::spawn(async move {
                databento_inference::run(inference_config, inference_root, inference_receiver).await
            }));
            live_supervisor = Some(tokio::spawn(async move {
                databento_live::run_equities_stream(
                    &data_config,
                    &live_config,
                    status_path,
                    bars_path,
                    database_path,
                    Some(inference_sender),
                )
                .await
            }));
        } else {
            let status_path = root.join("live/status.json");
            let tcp_status = live::check(&config.live, &config.live.host, config.live.port);
            let previous = std::fs::read(&status_path)
                .ok()
                .and_then(|bytes| serde_json::from_slice::<live::OpenDCheck>(&bytes).ok());
            let status = previous
                .filter(|row| {
                    tcp_status.tcp_connected
                        && row.status == "CONNECTED_QUOTE_PROTOCOL_VERIFIED"
                        && row.login_status == "VERIFIED_BY_OFFICIAL_SDK_CALLBACK"
                })
                .unwrap_or(tcp_status);
            std::fs::write(&status_path, serde_json::to_vec_pretty(&status)?)?;
            tracing::info!(status = %status.status, "legacy Moomoo readiness check");
        }
    }
    match (live_supervisor, inference_supervisor) {
        (Some(mut live_supervisor), Some(mut inference_supervisor)) => {
            tokio::select! {
                api_result = api::serve(config) => api_result,
                supervisor_result = &mut live_supervisor => match supervisor_result {
                    Ok(Ok(())) => anyhow::bail!("DATABENTO_LIVE_SUPERVISOR_EXITED_UNEXPECTEDLY"),
                    Ok(Err(error)) => Err(error),
                    Err(error) => Err(error.into()),
                },
                inference_result = &mut inference_supervisor => match inference_result {
                    Ok(Ok(())) => anyhow::bail!("DATABENTO_INFERENCE_SUPERVISOR_EXITED_UNEXPECTEDLY"),
                    Ok(Err(error)) => Err(error),
                    Err(error) => Err(error.into()),
                },
            }
        }
        (Some(mut live_supervisor), None) => tokio::select! {
            api_result = api::serve(config) => api_result,
            supervisor_result = &mut live_supervisor => match supervisor_result {
                Ok(Ok(())) => anyhow::bail!("LIVE_SUPERVISOR_EXITED_UNEXPECTEDLY"),
                Ok(Err(error)) => Err(error),
                Err(error) => Err(error.into()),
            },
        },
        (None, Some(_)) => {
            anyhow::bail!("INFERENCE_SUPERVISOR_STARTED_WITHOUT_LIVE_SUPERVISOR")
        }
        (None, None) => api::serve(config).await,
    }
}
