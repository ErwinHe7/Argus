import { createApp } from "./app.ts";
import { validateBindings, type Bindings } from "./config/env.ts";

const app = createApp();

const worker = {
  fetch(request, environment, executionContext) {
    const bindings = validateBindings(environment);
    return app.fetch(request, bindings, executionContext);
  },
  async scheduled(_controller, environment, _executionContext) {
    validateBindings(environment);
  },
  async queue(_batch, environment, _executionContext) {
    validateBindings(environment);
  },
} satisfies ExportedHandler<Bindings>;

export default worker;
