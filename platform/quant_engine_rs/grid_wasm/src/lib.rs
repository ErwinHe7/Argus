//! Browser-local adapter over the canonical Rust grid research engine.
//! This crate has no network, storage, broker or authentication capability.
#[path = "../../src/strategy_lab/decimal.rs"]
pub mod decimal;
#[path = "../../src/strategy_lab/grid/mod.rs"]
pub mod grid;

const MAX_INPUT_BYTES: usize = 4 * 1024 * 1024;

pub fn compute_json(input: &[u8]) -> Vec<u8> {
    let result = if input.len() > MAX_INPUT_BYTES {
        Err(anyhow::anyhow!("Grid request exceeds 4 MiB. Use a smaller dataset."))
    } else {
        serde_json::from_slice::<grid::GridReplayRequest>(input)
            .map_err(anyhow::Error::from)
            .and_then(|request| grid::replay(&request))
    };
    let response = match result {
        Ok(result) => serde_json::json!({"ok": true, "result": result}),
        Err(error) => serde_json::json!({"ok": false, "error": error.to_string()}),
    };
    serde_json::to_vec(&response).expect("finite grid response")
}

#[unsafe(no_mangle)]
pub extern "C" fn grid_alloc(length: u32) -> *mut u8 {
    if length == 0 || length as usize > MAX_INPUT_BYTES {
        return std::ptr::null_mut();
    }
    Box::into_raw(vec![0_u8; length as usize].into_boxed_slice()).cast::<u8>()
}

/// # Safety
/// Pointer and length must refer to an allocation from this instance. The
/// returned u64 packs the output pointer above its byte length. Free each
/// allocation exactly once with grid_dealloc after copying the response.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn grid_compute(pointer: *const u8, length: u32) -> u64 {
    let output = if pointer.is_null() || length as usize > MAX_INPUT_BYTES {
        compute_json(&[])
    } else {
        compute_json(unsafe { std::slice::from_raw_parts(pointer, length as usize) })
    };
    let length = output.len() as u32;
    let pointer = Box::into_raw(output.into_boxed_slice()).cast::<u8>() as u32;
    ((pointer as u64) << 32) | u64::from(length)
}

/// # Safety
/// Pointer and length must exactly match a live buffer returned by grid_alloc
/// or grid_compute in this instance. Do not free a buffer twice.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn grid_dealloc(pointer: *mut u8, length: u32) {
    if !pointer.is_null() {
        let slice = std::ptr::slice_from_raw_parts_mut(pointer, length as usize);
        drop(unsafe { Box::from_raw(slice) });
    }
}

#[cfg(test)]
mod tests {
    #[test]
    fn malformed_or_oversized_requests_return_explicit_errors() {
        for bytes in [b"{}".to_vec(), b"null".to_vec(), vec![b'x'; super::MAX_INPUT_BYTES + 1]] {
            let output: serde_json::Value = serde_json::from_slice(&super::compute_json(&bytes)).unwrap();
            assert_eq!(output["ok"], false);
            assert!(output.get("result").is_none());
        }
    }
}
