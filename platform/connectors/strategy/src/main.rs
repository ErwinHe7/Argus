use anyhow::Result;
use clap::{Parser, Subcommand};
use leo_strategy_connector::runtime;
use std::{
    io::{self, Read},
    path::PathBuf,
};

#[derive(Parser)]
#[command(
    version,
    about = "Leo paper strategy connector. No live order capability."
)]
struct Cli {
    #[arg(long)]
    state_dir: Option<PathBuf>,
    #[command(subcommand)]
    command: Action,
}
#[derive(Subcommand)]
enum Action {
    /// Read the one-use pairing token from stdin; it is never an argument or log.
    Pair {
        #[arg(long)]
        api_base: String,
        #[arg(long)]
        name: String,
        #[arg(long)]
        engine: PathBuf,
        #[arg(long)]
        adapter: PathBuf,
        #[arg(long)]
        adapter_argument: Vec<String>,
        #[arg(long)]
        allow_local_control_for_development: bool,
    },
    /// Poll outbound control and run authorized dry/paper mandates.
    Run {
        #[arg(long)]
        once: bool,
    },
    /// Report local installation only. Does not contact a broker or read credentials.
    Doctor,
    /// Upload an existing local research report; never uploads price histories.
    UploadReport {
        #[arg(long)]
        research_run_id: String,
        #[arg(long)]
        report: PathBuf,
    },
    /// Explicitly accept a verified flat paper account reset/manual change. No orders.
    ResolveFlatAccount {
        #[arg(long)]
        account_id: String,
        #[arg(long, required = true)]
        accept_flat_paper_reset: bool,
    },
}
fn main() {
    if let Err(_error) = go() {
        eprintln!(
            "Connector operation failed. Check installation, OS credential store, control API, and the local redacted event journal. No retry of an uncertain order was submitted."
        );
        std::process::exit(1);
    }
}
fn go() -> Result<()> {
    let cli = Cli::parse();
    let dir = cli.state_dir.unwrap_or_else(runtime::state_dir);
    match cli.command {
        Action::Doctor => {
            println!(
                "{}",
                serde_json::json!({"version":env!("CARGO_PKG_VERSION"),"paperOnly":true,"stateDirectory":dir,"paired":dir.join("config.json").exists(),"brokerChecked":false,"controlPollSeconds":5,"entryLeaseSeconds":15,"protection":"local_software_stop_requires_running_computer"})
            );
            Ok(())
        }
        Action::Run { once } => runtime::run(&dir, once),
        Action::UploadReport {
            research_run_id,
            report,
        } => runtime::upload_report(&dir, &research_run_id, &report),
        Action::ResolveFlatAccount {
            account_id,
            accept_flat_paper_reset: _,
        } => runtime::resolve_flat_account(&dir, &account_id),
        Action::Pair {
            api_base,
            name,
            engine,
            adapter,
            adapter_argument,
            allow_local_control_for_development,
        } => {
            let mut token = String::new();
            io::stdin().take(129).read_to_string(&mut token)?;
            runtime::pair(
                &api_base,
                &name,
                token.trim(),
                &dir,
                &engine,
                &adapter,
                adapter_argument,
                allow_local_control_for_development,
            )
        }
    }
}
