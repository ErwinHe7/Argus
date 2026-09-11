//! Bounded, offline earnings-evidence comparison. Reads no credentials or network.
use axio_quant_engine::earnings_radar::{Request, compare};
use std::io::{Read, Write};

fn main() {
    let mut input = String::new();
    let result = std::io::stdin()
        .take(512 * 1024 + 1)
        .read_to_string(&mut input);
    let output = if result.is_err() || input.len() > 512 * 1024 {
        serde_json::json!({"schema_version":"leo-earnings-comparison.v1","status":"unavailable","reason_codes":["invalid_or_oversized_request"],"comparison":null,"prediction_enabled":false,"execution_enabled":false})
    } else {
        match serde_json::from_str::<Request>(&input) {
            Ok(request) => serde_json::to_value(compare(&request)).expect("finite report"),
            Err(_) => {
                serde_json::json!({"schema_version":"leo-earnings-comparison.v1","status":"unavailable","reason_codes":["invalid_request"],"comparison":null,"prediction_enabled":false,"execution_enabled":false})
            }
        }
    };
    let mut stdout = std::io::stdout().lock();
    if serde_json::to_writer(&mut stdout, &output).is_err() || writeln!(stdout).is_err() {
        std::process::exit(1);
    }
}
