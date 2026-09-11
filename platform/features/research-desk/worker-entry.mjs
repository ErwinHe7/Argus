// This entry wraps the retained release artifact. Do not rebuild unrelated Next
// source when publishing the homepage; stage this file beside frozen .open-next.
import originalWorker from '../../.open-next/worker.js';
import { createResearchHomeWorker } from './worker-routing.ts';

export { DOQueueHandler, DOShardedTagCache, BucketCachePurge } from '../../.open-next/worker.js';
export default createResearchHomeWorker(originalWorker);
