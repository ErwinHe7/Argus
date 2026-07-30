#![recursion_limit = "256"]

pub mod allocation;
pub mod analog_engine;
pub mod anomaly_research;
pub mod api;
pub mod broker;
pub mod config;
pub mod cross_asset;
pub mod data;
pub mod domain;
pub mod engine;
pub mod event_library;
pub mod factor_rank;
pub mod frozen_universe;
pub mod ledger;
pub mod live;
pub mod market_memory;
pub mod market_query;
pub mod market_state;
pub mod missing_data;
pub mod motif_discovery;
pub mod nonlinear_models;
pub mod offline_model_validation;
pub mod os;
pub mod os_domain;
pub mod pattern_factory;
pub mod portfolio_risk;
pub mod prediction_explanation;
pub mod prediction_ledger;
pub mod predictor;
pub mod probability_calibration;
pub mod production_readiness;
pub mod promotion_registry;
pub mod registry;
pub mod research_api;
pub mod risk_policy;
pub mod weak_signal;

pub use config::AppConfig;

/// Databento and the native WebSocket client currently enable different
/// rustls provider features in the same process. Install one deterministic
/// provider before any TLS client is constructed instead of letting rustls
/// guess (and panic) at runtime.
pub fn install_tls_crypto_provider() {
    let _ = rustls::crypto::ring::default_provider().install_default();
}
