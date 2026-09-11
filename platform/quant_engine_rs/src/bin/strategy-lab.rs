//! Offline one-request/one-response JSON boundary. Never loads credentials.
use anyhow::{Result, ensure};
use axio_quant_engine::strategy_lab::{self, Decimal, Strategy};
use serde::Deserialize;
use std::io::{Read, Write};

#[derive(Deserialize)]
#[serde(tag = "operation", rename_all = "snake_case")]
enum Request {
    Evaluate {
        #[serde(flatten)]
        request: strategy_lab::EvaluateRequest,
    },
    Size {
        #[serde(flatten)]
        request: strategy_lab::SizeRequest,
    },
    Stop {
        strategy: Strategy,
        first_fill_price: Decimal,
        signal_atr: Decimal,
    },
    Replay {
        #[serde(flatten)]
        request: strategy_lab::ReplayRequest,
    },
    GridReplay {
        #[serde(flatten)]
        request: strategy_lab::grid::GridReplayRequest,
    },
}

fn run() -> Result<serde_json::Value> {
    let mut input = String::new();
    std::io::stdin()
        .take(32 * 1024 * 1024 + 1)
        .read_to_string(&mut input)?;
    ensure!(
        input.len() <= 32 * 1024 * 1024,
        "request exceeds byte limit"
    );
    match serde_json::from_str::<Request>(&input)? {
        Request::Evaluate { request } => {
            Ok(serde_json::to_value(strategy_lab::evaluate(&request)?)?)
        }
        Request::Size { request } => Ok(serde_json::to_value(strategy_lab::size_entry(&request)?)?),
        Request::Stop {
            strategy,
            first_fill_price,
            signal_atr,
        } => Ok(
            serde_json::json!({"initial_stop": strategy_lab::initial_stop(strategy, first_fill_price, signal_atr)?}),
        ),
        Request::Replay { request } => Ok(serde_json::to_value(strategy_lab::replay(&request)?)?),
        Request::GridReplay { request } => {
            Ok(serde_json::to_value(strategy_lab::grid::replay(&request)?)?)
        }
    }
}
fn main() {
    let (output, status) = match run() {
        Ok(result) => (result, 0),
        Err(error) => (
            serde_json::json!({"error": error.to_string(), "execution_authorized": false}),
            1,
        ),
    };
    let serialized = serde_json::to_vec(&output).expect("finite JSON response");
    if std::io::stdout().write_all(&serialized).is_err() {
        std::process::exit(1);
    }
    std::process::exit(status);
}
