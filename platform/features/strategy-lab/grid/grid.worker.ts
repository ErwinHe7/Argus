interface GridExports extends WebAssembly.Exports {
  memory: WebAssembly.Memory;
  grid_alloc(length: number): number;
  grid_compute(pointer: number, length: number): bigint;
  grid_dealloc(pointer: number, length: number): void;
}

self.onmessage = async (event: MessageEvent<unknown>) => {
  try {
    if (typeof event.data !== 'string') throw new Error('Grid request must be JSON text.');
    const input = new TextEncoder().encode(event.data);
    if (input.byteLength === 0 || input.byteLength > 4 * 1024 * 1024) throw new Error('Grid input must be between 1 byte and 4 MiB.');
    const response = await fetch('/app/research-desk/grid/leo_grid_wasm.wasm');
    if (!response.ok) throw new Error('The local grid engine is unavailable. Reload and retry.');
    const { instance } = await WebAssembly.instantiate(await response.arrayBuffer(), {});
    const engine = instance.exports as GridExports;
    const pointer = engine.grid_alloc(input.byteLength);
    if (!pointer) throw new Error('The grid engine could not allocate input memory.');
    let outputPointer = 0;
    let outputLength = 0;
    try {
      new Uint8Array(engine.memory.buffer, pointer, input.byteLength).set(input);
      const packed = engine.grid_compute(pointer, input.byteLength);
      outputPointer = Number(packed >> 32n);
      outputLength = Number(packed & 0xffffffffn);
      if (outputLength > 64 * 1024 * 1024) throw new Error('Grid report is too large. Use fewer sessions or intervals.');
      const output = new TextDecoder().decode(new Uint8Array(engine.memory.buffer, outputPointer, outputLength));
      self.postMessage(JSON.parse(output));
    } finally {
      if (outputPointer) engine.grid_dealloc(outputPointer, outputLength);
      engine.grid_dealloc(pointer, input.byteLength);
    }
  } catch (error) {
    self.postMessage({ok: false, error: error instanceof Error ? error.message : 'The local grid replay failed.'});
  }
};
