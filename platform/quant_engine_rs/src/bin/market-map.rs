use anyhow::{Context, Result, ensure};
use axio_quant_engine::market_map::{
    MarketMapInput, PublicMarketMapInput, build_public_snapshot, build_snapshot,
    illustrative_review_for_horizon,
};
use clap::Parser;
use std::{fs, path::PathBuf};

#[derive(Parser)]
#[command(
    about = "Export validated daily Market Map research; no orders or live synthetic fallback"
)]
struct Cli {
    /// JSON input with observed bars, same-tenor IV, benchmark, source rights and calendar.
    #[arg(long, conflicts_with = "example", required_unless_present = "example")]
    input: Option<PathBuf>,
    /// Output file. A failed input leaves the existing output untouched.
    #[arg(long)]
    output: PathBuf,
    /// Generate an explicitly marked synthetic visual review envelope, never live data.
    #[arg(long)]
    example: bool,
    /// Projection horizon for synthetic visual review only.
    #[arg(long, default_value = "20d", requires = "example")]
    horizon: String,
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    let value = if cli.example {
        illustrative_review_for_horizon(&cli.horizon)?
    } else {
        let path = cli.input.context("--input is required")?;
        let input: serde_json::Value =
            serde_json::from_slice(&fs::read(path)?).context("invalid Market Map input JSON")?;
        if input.get("mode").and_then(serde_json::Value::as_str) == Some("public_market") {
            let public: PublicMarketMapInput = serde_json::from_value(input)
                .context("invalid public Market Map input contract")?;
            build_public_snapshot(&public)?
        } else {
            let member: MarketMapInput = serde_json::from_value(input)
                .context("invalid member Market Map input contract")?;
            build_snapshot(&member)?
        }
    };
    let bytes = serde_json::to_vec(&value)?;
    ensure!(!bytes.is_empty(), "empty artifact");
    if let Some(parent) = cli
        .output
        .parent()
        .filter(|parent| !parent.as_os_str().is_empty())
    {
        fs::create_dir_all(parent)?;
    }
    fs::write(&cli.output, bytes).context("writing Market Map artifact")?;
    eprintln!("Market Map artifact written: {}", cli.output.display());
    Ok(())
}
