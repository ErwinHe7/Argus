//! Minimal byte-buffer ABI around the canonical Rust Market Map implementation.
//! This crate neither fetches data nor possesses membership or vendor credentials.
#[path = "../../src/market_map.rs"]
pub mod market_map;

const MAX_INPUT_BYTES: usize = 4 * 1024 * 1024;

pub fn compute_json(input: &[u8]) -> Vec<u8> {
    let result = if input.len() > MAX_INPUT_BYTES {
        Err(anyhow::anyhow!("public market input exceeds size limit"))
    } else {
        serde_json::from_slice::<market_map::PublicMarketMapInput>(input)
            .map_err(anyhow::Error::from)
            .and_then(|request| market_map::build_public_snapshot(&request))
    };
    let response = match result {
        Ok(snapshot) => serde_json::json!({"ok":true,"snapshot":snapshot}),
        Err(error) => serde_json::json!({"ok":false,"error":error.to_string()}),
    };
    serde_json::to_vec(&response).expect("validated JSON response must serialize")
}

/// Allocate a byte slice. The caller must free the returned pointer with exactly
/// the same length using `mm_dealloc`, after `mm_compute` has read the input.
#[unsafe(no_mangle)]
pub extern "C" fn mm_alloc(length: u32) -> *mut u8 {
    if length as usize > MAX_INPUT_BYTES {
        return std::ptr::null_mut();
    }
    let bytes = vec![0_u8; length as usize].into_boxed_slice();
    Box::into_raw(bytes).cast::<u8>()
}

/// # Safety
/// `pointer` must refer to `length` readable bytes in this instance's linear memory.
/// The result packs output pointer in the upper 32 bits and byte length in the
/// lower 32 bits. Both buffers remain owned by the caller until `mm_dealloc`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn mm_compute(pointer: *const u8, length: u32) -> u64 {
    let bytes = if pointer.is_null() || length as usize > MAX_INPUT_BYTES {
        compute_json(&[])
    } else {
        compute_json(unsafe { std::slice::from_raw_parts(pointer, length as usize) })
    };
    let output = bytes.into_boxed_slice();
    let length = output.len() as u32;
    let pointer = Box::into_raw(output).cast::<u8>() as u32;
    ((pointer as u64) << 32) | length as u64
}

/// # Safety
/// `pointer` and `length` must exactly match a still-live allocation returned by
/// `mm_alloc` or `mm_compute` from the same WebAssembly instance. Free only once.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn mm_dealloc(pointer: *mut u8, length: u32) {
    if !pointer.is_null() {
        let slice = std::ptr::slice_from_raw_parts_mut(pointer, length as usize);
        drop(unsafe { Box::from_raw(slice) });
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn wasm_json_boundary_rejects_member_or_malformed_inputs() {
        for bytes in [
            b"not json".as_slice(),
            b"{}",
            b"{\"mode\":\"member_equity\"}",
        ] {
            let value: serde_json::Value = serde_json::from_slice(&compute_json(bytes)).unwrap();
            assert_eq!(value["ok"], false);
            assert!(value.get("snapshot").is_none());
        }
    }
}
