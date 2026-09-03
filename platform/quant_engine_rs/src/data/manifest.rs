use std::{
    fs,
    io::Read,
    path::{Path, PathBuf},
};

use anyhow::{Context, Result};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

use crate::config::DataRequest;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DataManifest {
    pub manifest_version: u32,
    pub provider: String,
    pub request: DataRequest,
    pub raw_path: PathBuf,
    pub bytes: u64,
    pub sha256: String,
    pub acquired_at: DateTime<Utc>,
    pub license_note: String,
    pub synthetic: bool,
}

pub fn sha256_file(path: &Path) -> Result<String> {
    let mut file = fs::File::open(path)
        .with_context(|| format!("failed opening {} for checksum", path.display()))?;
    let mut hasher = Sha256::new();
    // Keep the checksum buffer on the heap. A 1 MiB stack allocation overflows
    // the default Windows main-thread stack in the production CLI.
    let mut buffer = vec![0_u8; 1024 * 1024];
    loop {
        let count = file.read(&mut buffer)?;
        if count == 0 {
            break;
        }
        hasher.update(&buffer[..count]);
    }
    Ok(format!("{:x}", hasher.finalize()))
}

pub fn write_manifest(root: &Path, manifest: &DataManifest) -> Result<PathBuf> {
    fs::create_dir_all(root)?;
    let path = root.join(format!(
        "{}__{}.manifest.json",
        manifest.request.name,
        manifest.acquired_at.format("%Y%m%dT%H%M%SZ")
    ));
    let payload = serde_json::to_vec_pretty(manifest)?;
    fs::write(&path, payload)?;
    Ok(path)
}

#[cfg(test)]
mod tests {
    use std::fs;

    use tempfile::tempdir;

    use super::sha256_file;

    #[test]
    fn checksum_is_deterministic_and_content_sensitive() {
        let directory = tempdir().unwrap();
        let path = directory.path().join("raw.dbn.zst");
        fs::write(&path, b"immutable vendor bytes").unwrap();
        let first = sha256_file(&path).unwrap();
        let second = sha256_file(&path).unwrap();
        assert_eq!(first, second);

        fs::write(&path, b"changed vendor bytes").unwrap();
        assert_ne!(first, sha256_file(&path).unwrap());
    }
}
