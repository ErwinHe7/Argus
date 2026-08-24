import { createApp } from "./app.ts";
import { validateBindings, type Bindings } from "./config/env.ts";
import { runQueue } from "./jobs/queue-runtime.ts";
import { runScheduled } from "./jobs/scheduled.ts";

const app = createApp();

const worker = {
  fetch(request, environment, executionContext) {
    const bindings = validateBindings(environment);
    return app.fetch(request, bindings, executionContext);
  },
  async scheduled(controller, environment, executionContext) {
    const bindings = validateBindings(environment);
    executionContext.waitUntil(runScheduled(controller, bindings));
  },
  async queue(batch, environment, executionContext) {
    const bindings = validateBindings(environment);
    executionContext.waitUntil(runQueue(batch, bindings));
  },
} satisfies ExportedHandler<Bindings>;

export default worker;
