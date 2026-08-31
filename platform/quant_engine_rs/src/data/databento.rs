use std::{fs, path::Path};

use anyhow::{Context, Result, bail};
use chrono::Utc;
use databento::{
    HistoricalClient,
    dbn::{SType, Schema},
    historical::{
        metadata::{GetBillableSizeParams, GetCostParams, GetRecordCountParams},
        timeseries::GetRangeParams,
    },
};
use time::{OffsetDateTime, format_description::well_known::Rfc3339};

use crate::{
    config::{DataConfig, DataRequest},
    data::{
        CostEstimate, DownloadReceipt,
        manifest::{DataManifest, sha256_file, write_manifest},
        request_output_path,
    },
};

fn request_parts(request: &DataRequest) -> Result<(Schema, SType, OffsetDateTime, OffsetDateTime)> {
    let schema: Schema = request
        .schema
        .parse()
        .with_context(|| format!("unsupported DBN schema {}", request.schema))?;
    let stype: SType = request
        .stype_in
        .parse()
        .with_context(|| format!("unsupported Databento stype {}", request.stype_in))?;
    let start = OffsetDateTime::parse(&request.start, &Rfc3339)
        .with_context(|| format!("invalid start {}", request.start))?;
    let end = OffsetDateTime::parse(&request.end, &Rfc3339)
        .with_context(|| format!("invalid end {}", request.end))?;
    Ok((schema, stype, start, end))
}

pub async fn estimate_cost(request: &DataRequest) -> Result<CostEstimate> {
    let (schema, stype, start, end) = request_parts(request)?;
    let mut client = HistoricalClient::builder().key_from_env()?.build()?;
    let count_params = GetRecordCountParams::builder()
        .dataset(&request.dataset)
        .symbols(request.symbols.clone())
        .schema(schema)
        .date_time_range(start..end)
        .stype_in(stype)
        .build();
    let size_params = GetBillableSizeParams::builder()
        .dataset(&request.dataset)
        .symbols(request.symbols.clone())
        .schema(schema)
        .date_time_range(start..end)
        .stype_in(stype)
        .build();
    let cost_params = GetCostParams::builder()
        .dataset(&request.dataset)
        .symbols(request.symbols.clone())
        .schema(schema)
        .date_time_range(start..end)
        .stype_in(stype)
        .build();
    let estimated_records = client.metadata().get_record_count(&count_params).await?;
    let estimated_bytes = client.metadata().get_billable_size(&size_params).await?;
    let estimated_cost_usd = client.metadata().get_cost(&cost_params).await?;
    Ok(CostEstimate {
        request_name: request.name.clone(),
        dataset: request.dataset.clone(),
        schema: request.schema.clone(),
        symbols: request.symbols.clone(),
        start: request.start.clone(),
        end: request.end.clone(),
        estimated_records,
        estimated_bytes,
        estimated_cost_usd,
        warning: "Estimate only. No data is downloaded or purchased without explicit confirmation and a maximum cost cap.".to_string(),
    })
}

pub async fn download(
    data: &DataConfig,
    request: &DataRequest,
    confirm_cost: bool,
    maximum_cost_usd: f64,
) -> Result<DownloadReceipt> {
    if !confirm_cost {
        bail!(
            "download refused: run `quantctl data cost --request {}` then pass --confirm-cost",
            request.name
        );
    }
    let estimate = estimate_cost(request).await?;
    if estimate.estimated_cost_usd > maximum_cost_usd {
        bail!(
            "estimated cost ${:.2} exceeds --maximum-cost-usd ${:.2}",
            estimate.estimated_cost_usd,
            maximum_cost_usd
        );
    }
    let (schema, stype, start, end) = request_parts(request)?;
    let path = request_output_path(&data.raw_root, request);
    if path.exists() {
        bail!(
            "refusing to overwrite immutable raw data {}",
            path.display()
        );
    }
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }

    let params = GetRangeParams::builder()
        .dataset(&request.dataset)
        .symbols(request.symbols.clone())
        .schema(schema)
        .date_time_range(start..end)
        .stype_in(stype)
        .build()
        .with_path(&path);
    let mut client = HistoricalClient::builder().key_from_env()?.build()?;
    let _decoder = client.timeseries().get_range_to_file(&params).await?;

    let bytes = fs::metadata(&path)
        .with_context(|| format!("download did not create {}", path.display()))?
        .len();
    let sha256 = sha256_file(&path)?;
    let manifest = DataManifest {
        manifest_version: 1,
        provider: "Databento".to_string(),
        request: request.clone(),
        raw_path: path.clone(),
        bytes,
        sha256: sha256.clone(),
        acquired_at: Utc::now(),
        license_note: "Licensed Databento data; redistribution is not implied.".to_string(),
        synthetic: false,
    };
    let manifest_path = write_manifest(Path::new(&data.manifest_root), &manifest)?;
    Ok(DownloadReceipt {
        path,
        bytes,
        sha256,
        manifest_path,
    })
}
