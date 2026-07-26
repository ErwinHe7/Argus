//! Exact, fail-closed loading for the live multi-symbol predictor universe.
//!
//! The live workers consume the offline-written universe registry.  A model is
//! selected only by its exact canonical `model_symbol`; the primary research
//! target is never used as a fallback for another symbol.

use std::{
    collections::{BTreeMap, BTreeSet},
    fs,
    path::{Path, PathBuf},
};

use anyhow::{Context, Result, bail};
use serde::Deserialize;

use crate::predictor::FrozenPredictorArtifact;

pub const FROZEN_UNIVERSE_REGISTRY_VERSION: &str = "axio.frozen-universe-registry.v1";

#[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
pub struct FrozenUniverseEntry {
    pub public_symbol: String,
    pub model_symbol: String,
    pub artifact_path: String,
    pub artifact_version: String,
    pub model_hash: String,
}

#[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
pub struct FrozenUniverseRegistry {
    pub schema_version: String,
    pub entries: Vec<FrozenUniverseEntry>,
}

#[derive(Debug, Default)]
pub struct LoadedFrozenUniverse {
    artifacts: BTreeMap<String, FrozenPredictorArtifact>,
    failures: BTreeMap<String, String>,
}

impl LoadedFrozenUniverse {
    pub fn unavailable_for_symbols<I, S>(requested_symbols: I, reason: &str) -> Self
    where
        I: IntoIterator<Item = S>,
        S: AsRef<str>,
    {
        let failures = requested_symbols
            .into_iter()
            .filter_map(|symbol| {
                canonical_model_symbol(symbol.as_ref())
                    .ok()
                    .map(|symbol| (symbol, reason.to_string()))
            })
            .collect();
        Self {
            artifacts: BTreeMap::new(),
            failures,
        }
    }

    pub fn artifact(&self, model_symbol: &str) -> Option<&FrozenPredictorArtifact> {
        canonical_model_symbol(model_symbol)
            .ok()
            .and_then(|symbol| self.artifacts.get(&symbol))
    }

    pub fn artifacts(&self) -> &BTreeMap<String, FrozenPredictorArtifact> {
        &self.artifacts
    }

    pub fn failures(&self) -> &BTreeMap<String, String> {
        &self.failures
    }

    pub fn requested_symbol_count(&self) -> usize {
        self.artifacts.len() + self.failures.len()
    }

    pub fn into_parts(
        self,
    ) -> (
        BTreeMap<String, FrozenPredictorArtifact>,
        BTreeMap<String, String>,
    ) {
        (self.artifacts, self.failures)
    }
}

impl FrozenUniverseRegistry {
    pub fn from_path(path: &Path) -> Result<Self> {
        let registry: Self = serde_json::from_slice(
            &fs::read(path).with_context(|| format!("read {}", path.display()))?,
        )
        .with_context(|| format!("deserialize {}", path.display()))?;
        if registry.schema_version != FROZEN_UNIVERSE_REGISTRY_VERSION {
            bail!(
                "unsupported frozen universe registry version {}",
                registry.schema_version
            );
        }
        Ok(registry)
    }

    /// Return the one exact registry entry for each requested model symbol.
    ///
    /// Missing and duplicate entries are isolated to that symbol. In
    /// particular, a missing NVDA entry can never resolve to the SPY entry.
    pub fn exact_coverage<I, S>(
        &self,
        requested_symbols: I,
    ) -> BTreeMap<String, Result<&FrozenUniverseEntry, String>>
    where
        I: IntoIterator<Item = S>,
        S: AsRef<str>,
    {
        let requested = requested_symbols
            .into_iter()
            .filter_map(|symbol| canonical_model_symbol(symbol.as_ref()).ok())
            .collect::<BTreeSet<_>>();
        let mut coverage = BTreeMap::new();
        for requested_symbol in requested {
            let matches = self
                .entries
                .iter()
                .filter(|entry| {
                    canonical_model_symbol(&entry.model_symbol)
                        .is_ok_and(|symbol| symbol == requested_symbol)
                })
                .collect::<Vec<_>>();
            let result = match matches.as_slice() {
                [entry] => Ok(*entry),
                [] => Err("REGISTRY_ENTRY_MISSING".to_string()),
                _ => Err("REGISTRY_MODEL_SYMBOL_AMBIGUOUS".to_string()),
            };
            coverage.insert(requested_symbol, result);
        }
        coverage
    }
}

/// Load every configured model independently. Static artifact validation and
/// registry identity checks retain their existing content-hash gates. A bad or
/// absent artifact is recorded for only its own symbol.
pub fn load_frozen_universe<I, S>(
    registry_path: &Path,
    requested_symbols: I,
) -> Result<LoadedFrozenUniverse>
where
    I: IntoIterator<Item = S>,
    S: AsRef<str>,
{
    let registry = FrozenUniverseRegistry::from_path(registry_path)?;
    let mut loaded = LoadedFrozenUniverse::default();
    for (model_symbol, entry) in registry.exact_coverage(requested_symbols) {
        let entry = match entry {
            Ok(entry) => entry,
            Err(reason) => {
                loaded.failures.insert(model_symbol, reason);
                continue;
            }
        };
        match load_exact_artifact(registry_path, entry, &model_symbol) {
            Ok(artifact) => {
                loaded.artifacts.insert(model_symbol, artifact);
            }
            Err(error) => {
                loaded.failures.insert(model_symbol, error.to_string());
            }
        }
    }
    Ok(loaded)
}

fn load_exact_artifact(
    registry_path: &Path,
    entry: &FrozenUniverseEntry,
    requested_model_symbol: &str,
) -> Result<FrozenPredictorArtifact> {
    let artifact_path = resolve_artifact_path(registry_path, &entry.artifact_path);
    let artifact: FrozenPredictorArtifact = serde_json::from_slice(
        &fs::read(&artifact_path).with_context(|| format!("read {}", artifact_path.display()))?,
    )
    .with_context(|| format!("deserialize {}", artifact_path.display()))?;
    artifact
        .validate_static()
        .with_context(|| format!("validate {}", artifact_path.display()))?;
    if !artifact.target.eq_ignore_ascii_case(requested_model_symbol)
        || !entry
            .model_symbol
            .eq_ignore_ascii_case(requested_model_symbol)
    {
        bail!(
            "REGISTRY_ARTIFACT_TARGET_MISMATCH requested={} entry={} artifact={}",
            requested_model_symbol,
            entry.model_symbol,
            artifact.target
        );
    }
    if artifact.artifact_version != entry.artifact_version {
        bail!("REGISTRY_ARTIFACT_VERSION_MISMATCH requested={requested_model_symbol}");
    }
    if artifact.model_hash != entry.model_hash {
        bail!("REGISTRY_MODEL_HASH_MISMATCH requested={requested_model_symbol}");
    }
    Ok(artifact)
}

pub fn canonical_model_symbol(raw: &str) -> Result<String> {
    let canonical = raw
        .trim()
        .strip_prefix("US.")
        .unwrap_or(raw.trim())
        .to_ascii_uppercase();
    if canonical.is_empty()
        || !canonical
            .chars()
            .all(|character| character.is_ascii_alphanumeric())
    {
        bail!("invalid model symbol {raw:?}");
    }
    Ok(canonical)
}

fn resolve_artifact_path(_registry_path: &Path, raw: &str) -> PathBuf {
    // Registry paths are written on both Windows and Linux. Treat either
    // separator as a path separator so a Windows-generated registry remains
    // usable in the Linux production container.
    PathBuf::from(raw.replace('\\', "/"))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn entry(public_symbol: &str, model_symbol: &str) -> FrozenUniverseEntry {
        FrozenUniverseEntry {
            public_symbol: public_symbol.to_string(),
            model_symbol: model_symbol.to_string(),
            artifact_path: format!("data/models/universe/{public_symbol}.frozen.json"),
            artifact_version: "axio.frozen-predictor.v1".to_string(),
            model_hash: format!("{model_symbol}-hash"),
        }
    }

    #[test]
    fn exact_coverage_resolves_multiple_model_symbols_independently() {
        let registry = FrozenUniverseRegistry {
            schema_version: FROZEN_UNIVERSE_REGISTRY_VERSION.to_string(),
            entries: vec![
                entry("SPX", "SPY"),
                entry("QQQ", "QQQ"),
                entry("NVDA", "NVDA"),
            ],
        };

        let coverage = registry.exact_coverage(["US.SPY", "US.QQQ", "US.NVDA"]);

        assert_eq!(coverage.len(), 3);
        assert_eq!(coverage["SPY"].as_ref().unwrap().public_symbol, "SPX");
        assert_eq!(coverage["QQQ"].as_ref().unwrap().public_symbol, "QQQ");
        assert_eq!(coverage["NVDA"].as_ref().unwrap().public_symbol, "NVDA");
    }

    #[test]
    fn missing_symbol_never_falls_back_to_spy() {
        let registry = FrozenUniverseRegistry {
            schema_version: FROZEN_UNIVERSE_REGISTRY_VERSION.to_string(),
            entries: vec![entry("SPX", "SPY")],
        };

        let coverage = registry.exact_coverage(["SPY", "NVDA"]);

        assert!(coverage["SPY"].is_ok());
        assert_eq!(
            coverage["NVDA"].as_ref().unwrap_err(),
            "REGISTRY_ENTRY_MISSING"
        );
    }

    #[test]
    fn duplicate_model_mapping_fails_only_the_ambiguous_symbol() {
        let registry = FrozenUniverseRegistry {
            schema_version: FROZEN_UNIVERSE_REGISTRY_VERSION.to_string(),
            entries: vec![
                entry("SPX", "SPY"),
                entry("SPY", "SPY"),
                entry("NVDA", "NVDA"),
            ],
        };

        let coverage = registry.exact_coverage(["SPY", "NVDA"]);

        assert_eq!(
            coverage["SPY"].as_ref().unwrap_err(),
            "REGISTRY_MODEL_SYMBOL_AMBIGUOUS"
        );
        assert!(coverage["NVDA"].is_ok());
    }

    #[test]
    fn windows_registry_paths_are_portable_to_linux() {
        let resolved = resolve_artifact_path(
            Path::new("data/models/universe/registry.json"),
            r"data\models\universe\NVDA.frozen.json",
        );

        assert_eq!(
            resolved,
            PathBuf::from("data/models/universe/NVDA.frozen.json")
        );
    }
}
