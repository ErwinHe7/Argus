import type { PublicMarketMapSnapshot } from '../../lib/market-map/types';
import { validatePublicMarketMapSnapshot } from '../../lib/market-map/validate';
import { PublicSourceError } from './sources';

export function computePublicSnapshot(module: WebAssembly.Module, input: unknown, now = new Date()): PublicMarketMapSnapshot {
  const instance = new WebAssembly.Instance(module, {});
  const exports = instance.exports;
  if (!(exports.memory instanceof WebAssembly.Memory) || typeof exports.mm_alloc !== 'function' ||
      typeof exports.mm_compute !== 'function' || typeof exports.mm_dealloc !== 'function') throw new PublicSourceError('wasm_abi_invalid');
  const memory = exports.memory;
  const encoded = new TextEncoder().encode(JSON.stringify(input));
  const inputPtr: number = exports.mm_alloc(encoded.length);
  let outputPtr = 0, outputLength = 0;
  try {
    new Uint8Array(memory.buffer, inputPtr, encoded.length).set(encoded);
    const result: bigint = exports.mm_compute(inputPtr, encoded.length);
    outputPtr = Number(result >> 32n);
    outputLength = Number(result & 0xffffffffn);
    if (outputLength <= 0 || outputLength > 4 * 1024 * 1024) throw new PublicSourceError('wasm_output_invalid');
    const text = new TextDecoder('utf-8', { fatal: true, ignoreBOM: false }).decode(new Uint8Array(memory.buffer, outputPtr, outputLength));
    const envelope: unknown = JSON.parse(text);
    if (!envelope || typeof envelope !== 'object' || !('ok' in envelope) || envelope.ok !== true || !('snapshot' in envelope)) throw new PublicSourceError('rust_market_map_rejected');
    const snapshot = validatePublicMarketMapSnapshot(envelope.snapshot, { now });
    if (!snapshot) throw new PublicSourceError('public_snapshot_contract_invalid');
    return snapshot;
  } finally {
    exports.mm_dealloc(inputPtr, encoded.length);
    if (outputPtr && outputLength) exports.mm_dealloc(outputPtr, outputLength);
  }
}
