use std::path::PathBuf;

use anyhow::Result;
use axio_quant_engine::{AppConfig, api, data::massive_live, live};
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
    api::serve(config).await
}
