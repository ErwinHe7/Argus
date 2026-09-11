import type { GridResult } from './types';
import { parseGridResult } from './validation';

/** Each replay gets an isolated worker. Termination also discards its WASM memory. */
export async function runGridReplay(request: unknown): Promise<GridResult> {
  const serialized = JSON.stringify(request);
  if (new TextEncoder().encode(serialized).byteLength > 4 * 1024 * 1024) {
    throw new Error('The grid request exceeds 4 MiB. Import a smaller dataset.');
  }
  return new Promise((resolve, reject) => {
    const worker = new Worker('/app/research-desk/grid/grid.worker.js', { type: 'module' });
    const finish = () => { clearTimeout(timer); worker.terminate(); };
    const timer = setTimeout(() => {
      finish(); reject(new Error('The grid replay timed out. Reduce the number of sessions or intervals and retry.'));
    }, 30_000);
    worker.onmessage = event => {
      finish();
      if (event.data?.ok === true && event.data.result?.schema_version === 'leo-grid-result.v1'
          && event.data.result.execution_authorized === false && event.data.result.paper_execution_available === false) {
        try { resolve(parseGridResult(event.data.result)); }
        catch (error) { reject(error instanceof Error ? error : new Error('The local engine returned an invalid report.')); }
      } else reject(new Error(typeof event.data?.error === 'string' ? event.data.error : 'The local engine returned an unsupported result. Retry after reloading.'));
    };
    worker.onerror = () => { finish(); reject(new Error('The local grid engine could not load. Reload this page and retry.')); };
    worker.postMessage(serialized);
  });
}
