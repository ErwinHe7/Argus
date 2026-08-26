const DEMO_PEERS = Object.freeze({
  production: "https://demo.just-build-this.app",
  beta: "https://demo-beta.just-build-this.app",
});

const LOCAL_COPY = Object.freeze({
  loading: "Opening a fresh Demo…",
  ready: "Demo ready. Enter the frame when you’re ready to explore.",
  error: "The Demo could not start. Your place on this page is unchanged.",
  "timed-out": "The Demo is taking longer than expected. Retry here or open it in a new tab.",
});

/** @typedef {'production' | 'beta'} DemoEnvironment */
/** @typedef {{ environment: DemoEnvironment, demoOrigin: string, protocols: readonly number[] }} DemoConfiguration */
/** @typedef {{ node: unknown, sourceWindow: unknown }} DemoFrame */

/**
 * Return a cryptographically random, URL-safe frame identity.
 * @param {Crypto} secureCrypto
 */
export function createAttemptId(secureCrypto = globalThis.crypto) {
  if (typeof secureCrypto?.randomUUID === "function") {
    return `frame-${secureCrypto.randomUUID()}`;
  }
  if (typeof secureCrypto?.getRandomValues !== "function") {
    throw new Error("Secure randomness is unavailable.");
  }
  const bytes = new Uint8Array(16);
  secureCrypto.getRandomValues(bytes);
  return `frame-${Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("")}`;
}

/** @param {DemoConfiguration} configuration */
function assertPairwiseConfiguration(configuration) {
  if (DEMO_PEERS[configuration.environment] !== configuration.demoOrigin) {
    throw new Error("Demo configuration does not match its environment peer.");
  }
  if (
    configuration.protocols.length !== 2 ||
    configuration.protocols[0] !== 2 ||
    configuration.protocols[1] !== 1
  ) {
    throw new Error("Demo protocol compatibility must be current plus previous.");
  }
}

/**
 * @param {DemoConfiguration} configuration
 * @param {string} attemptId
 */
export function buildDemoFrameUrl(configuration, attemptId) {
  assertPairwiseConfiguration(configuration);
  if (!/^[A-Za-z0-9._-]{1,96}$/.test(attemptId)) {
    throw new Error("Frame identity is not URL-safe.");
  }
  const url = new URL("/", configuration.demoOrigin);
  url.searchParams.set("environment", configuration.environment);
  url.searchParams.set("attempt", attemptId);
  return url.href;
}

/**
 * @param {{ origin?: unknown, source?: unknown, data?: unknown }} event
 * @param {{ configuration: DemoConfiguration, attemptId: string, frameWindow: unknown }} current
 */
export function validateDemoMessage(event, current) {
  if (event === null || typeof event !== "object") return null;
  if (event.origin !== current.configuration.demoOrigin || event.source !== current.frameWindow) return null;
  const data = event.data;
  if (data === null || typeof data !== "object" || Array.isArray(data)) return null;
  const message = /** @type {Record<string, unknown>} */ (data);
  if (message.source !== "ritual-investing-demo") return null;
  if (message.type !== "ritual-demo-ready" && message.type !== "ritual-demo-error") return null;
  if (
    typeof message.protocolVersion !== "number" ||
    !Number.isInteger(message.protocolVersion) ||
    !current.configuration.protocols.includes(message.protocolVersion)
  ) return null;
  if (message.environment !== current.configuration.environment) return null;
  if (message.attemptId !== current.attemptId) return null;
  return message.type === "ritual-demo-ready" ? "ready" : "error";
}

/**
 * @param {{
 *   configuration: DemoConfiguration,
 *   createAttemptId: () => string,
 *   createFrame: (url: string, attemptId: string) => DemoFrame,
 *   replaceFrame: (node: any) => void,
 *   scheduleTimeout: (callback: () => void, delay: number) => any,
 *   cancelTimeout: (handle: any) => void,
 *   update: (view: { state: string, message: string, retryVisible: boolean, resetVisible: boolean }) => void,
 *   timeoutMs?: number,
 * }} ports
 */
export function createDemoLifecycle(ports) {
  assertPairwiseConfiguration(ports.configuration);
  let current = /** @type {{ attemptId: string, frame: DemoFrame, timer: any } | null} */ (null);
  let destroyed = false;

  /** @param {'initial' | 'retry' | 'reset'} _reason */
  function replace(_reason) {
    if (destroyed) return;
    if (current !== null) ports.cancelTimeout(current.timer);
    const attemptId = ports.createAttemptId();
    const frame = ports.createFrame(buildDemoFrameUrl(ports.configuration, attemptId), attemptId);
    ports.replaceFrame(frame.node);
    const timer = ports.scheduleTimeout(() => {
      if (destroyed || current?.attemptId !== attemptId) return;
      ports.update({
        state: "timed-out",
        message: LOCAL_COPY["timed-out"],
        retryVisible: true,
        resetVisible: false,
      });
    }, ports.timeoutMs ?? 12_000);
    current = { attemptId, frame, timer };
    ports.update({
      state: "loading",
      message: LOCAL_COPY.loading,
      retryVisible: false,
      resetVisible: false,
    });
  }

  replace("initial");

  return Object.freeze({
    /** @param {{ origin?: unknown, source?: unknown, data?: unknown }} event */
    receiveMessage(event) {
      if (destroyed || current === null) return false;
      const state = validateDemoMessage(event, {
        configuration: ports.configuration,
        attemptId: current.attemptId,
        frameWindow: current.frame.sourceWindow,
      });
      if (state === null) return false;
      ports.cancelTimeout(current.timer);
      ports.update({
        state,
        message: LOCAL_COPY[state],
        retryVisible: state === "error",
        resetVisible: state === "ready",
      });
      return true;
    },
    retry() { replace("retry"); },
    reset() { replace("reset"); },
    destroy() {
      destroyed = true;
      if (current !== null) ports.cancelTimeout(current.timer);
    },
  });
}

const WAITLIST_COPY = Object.freeze({
  success: "Your provisional waitlist request was received. The address is not verified, and no message has been sent.",
  "field-error": "Enter a valid email and confirm the launch-contact notice.",
  "reload-required": "This privacy notice has changed. Reload the page before trying again.",
  retryable: "We couldn’t receive the request just now. Your email is still here; please try again.",
});

const TURNSTILE_SCRIPT_URL = "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit";

/**
 * @typedef {{
 *   render: (target: unknown, options: Record<string, unknown>) => string,
 *   reset: (widgetId: string) => void,
 * }} TurnstileApi
 */

/**
 * Keep the one-time widget token out of DOM queries and clear it after expiry,
 * provider error, or every endpoint attempt.
 * @param {{
 *   target: unknown,
 *   siteKey: string,
 *   load: () => Promise<TurnstileApi>,
 *   update: (state: 'ready' | 'verified' | 'verification-required' | 'unavailable') => void,
 * }} ports
 */
export function createTurnstileLifecycle(ports) {
  let api = /** @type {TurnstileApi | null} */ (null);
  let widgetId = /** @type {string | null} */ (null);
  let currentToken = "";

  const ready = (async () => {
    if (ports.siteKey.trim() === "") {
      ports.update("unavailable");
      return false;
    }
    try {
      api = await ports.load();
      widgetId = api.render(ports.target, {
        sitekey: ports.siteKey,
        action: "waitlist",
        callback(/** @type {string} */ token) {
          currentToken = typeof token === "string" && token.length <= 2_048 ? token : "";
          ports.update(currentToken === "" ? "verification-required" : "verified");
        },
        "expired-callback"() {
          currentToken = "";
          ports.update("verification-required");
        },
        "error-callback"() {
          currentToken = "";
          ports.update("unavailable");
        },
      });
      ports.update("ready");
      return true;
    } catch {
      api = null;
      widgetId = null;
      currentToken = "";
      ports.update("unavailable");
      return false;
    }
  })();

  return Object.freeze({
    ready,
    token() { return currentToken; },
    reset() {
      currentToken = "";
      if (api !== null && widgetId !== null) {
        try {
          api.reset(widgetId);
          ports.update("verification-required");
        } catch {
          ports.update("unavailable");
        }
      }
    },
  });
}

/** @returns {TurnstileApi | null} */
function installedTurnstile() {
  const candidate = Reflect.get(globalThis, "turnstile");
  if (candidate === null || typeof candidate !== "object") return null;
  const value = /** @type {Record<string, unknown>} */ (candidate);
  return typeof value.render === "function" && typeof value.reset === "function"
    ? /** @type {TurnstileApi} */ (candidate)
    : null;
}

/** @returns {Promise<TurnstileApi>} */
function loadTurnstileApi() {
  const installed = installedTurnstile();
  if (installed !== null) return Promise.resolve(installed);
  return new Promise((resolve, reject) => {
    const existing = document.querySelector("script[data-turnstile-loader]");
    const script = existing instanceof HTMLScriptElement ? existing : document.createElement("script");
    const loaded = () => {
      const api = installedTurnstile();
      if (api === null) reject(new Error("Turnstile did not initialize."));
      else resolve(api);
    };
    script.addEventListener("load", loaded, { once: true });
    script.addEventListener("error", () => reject(new Error("Turnstile is unavailable.")), { once: true });
    if (!(existing instanceof HTMLScriptElement)) {
      script.src = TURNSTILE_SCRIPT_URL;
      script.async = true;
      script.defer = true;
      script.referrerPolicy = "no-referrer";
      script.dataset.turnstileLoader = "explicit";
      document.head.appendChild(script);
    }
  });
}

/**
 * Bind the API request to the notice version actually rendered and checked.
 * @param {{
 *   email: string,
 *   consentChecked: boolean,
 *   consentNoticeVersion: string,
 *   renderedNoticeVersion: string,
 *   turnstileToken: string,
 * }} fields
 */
export function buildWaitlistRequest(fields) {
  if (!fields.consentChecked) throw new Error("Consent is required.");
  if (
    !/^waitlist-v\d+-\d{4}-\d{2}-\d{2}$/.test(fields.renderedNoticeVersion) ||
    fields.consentNoticeVersion !== fields.renderedNoticeVersion
  ) {
    throw new Error("Rendered waitlist notice does not match the consent value.");
  }
  if (fields.turnstileToken === "") throw new Error("Human verification is required.");
  return Object.freeze({
    email: fields.email,
    consent: true,
    noticeVersion: fields.renderedNoticeVersion,
    turnstileToken: fields.turnstileToken,
  });
}

/**
 * Convert an endpoint response into local, non-enumerating presentation copy.
 * @param {number} status
 * @param {unknown} body
 */
export function waitlistStateForResponse(status, body) {
  const code = body !== null && typeof body === "object" && !Array.isArray(body)
    ? /** @type {Record<string, unknown>} */ (body).code
    : undefined;
  const kind = status >= 200 && status < 300
    ? "success"
    : code === "stale_notice"
      ? "reload-required"
      : status === 400 || code === "invalid_email" || code === "invalid_request"
        ? "field-error"
        : "retryable";
  return Object.freeze({ kind, message: WAITLIST_COPY[kind] });
}

function installDemo() {
  const root = document.querySelector("[data-demo-environment]");
  const slot = document.querySelector("[data-demo-frame-slot]");
  const status = document.querySelector("[data-demo-status]");
  const retry = document.querySelector("[data-demo-retry]");
  const reset = document.querySelector("[data-demo-reset]");
  if (!(root instanceof HTMLElement) || !(slot instanceof HTMLElement) ||
      !(status instanceof HTMLElement) || !(retry instanceof HTMLButtonElement) ||
      !(reset instanceof HTMLButtonElement)) return;

  const environment = root.dataset.demoEnvironment;
  const demoOrigin = root.dataset.demoOrigin;
  if ((environment !== "production" && environment !== "beta") || demoOrigin === undefined) return;
  const configuration = /** @type {DemoConfiguration} */ ({ environment, demoOrigin, protocols: [2, 1] });
  const lifecycle = createDemoLifecycle({
    configuration,
    createAttemptId,
    createFrame(url) {
      const iframe = document.createElement("iframe");
      iframe.className = "demo-frame";
      iframe.title = "Explore the Ritual Investing product demo";
      iframe.setAttribute("sandbox", "allow-scripts allow-same-origin");
      iframe.setAttribute("loading", "eager");
      iframe.setAttribute("referrerpolicy", "no-referrer");
      iframe.src = url;
      return {
        node: iframe,
        get sourceWindow() { return iframe.contentWindow; },
      };
    },
    replaceFrame: (node) => slot.replaceChildren(node),
    scheduleTimeout: (callback, delay) => window.setTimeout(callback, delay),
    cancelTimeout: (handle) => window.clearTimeout(handle),
    update(view) {
      status.textContent = view.message;
      status.dataset.state = view.state;
      retry.hidden = !view.retryVisible;
      reset.hidden = !view.resetVisible;
    },
  });
  /** @param {MessageEvent} event */
  const onMessage = (event) => lifecycle.receiveMessage(event);
  window.addEventListener("message", onMessage);
  retry.addEventListener("click", () => lifecycle.retry());
  reset.addEventListener("click", () => lifecycle.reset());
  window.addEventListener("pagehide", () => {
    lifecycle.destroy();
    window.removeEventListener("message", onMessage);
  }, { once: true });
}

function installWaitlist() {
  const form = document.querySelector("[data-waitlist-form]");
  const email = document.querySelector("[data-waitlist-email]");
  const consent = document.querySelector("[data-waitlist-consent]");
  const feedback = document.querySelector("[data-waitlist-feedback]");
  const submit = document.querySelector("[data-waitlist-submit]");
  const mount = document.querySelector("[data-turnstile-mount]");
  if (!(form instanceof HTMLFormElement) || !(email instanceof HTMLInputElement) ||
      !(consent instanceof HTMLInputElement) || !(feedback instanceof HTMLElement) ||
      !(submit instanceof HTMLButtonElement) || !(mount instanceof HTMLElement)) return;

  const turnstileLifecycle = createTurnstileLifecycle({
    target: mount,
    siteKey: mount.dataset.turnstileSiteKey ?? "",
    load: loadTurnstileApi,
    update(state) {
      mount.dataset.state = state;
      const help = mount.querySelector("p");
      if (!(help instanceof HTMLElement)) return;
      if (state === "unavailable") {
        help.textContent = "Human verification is unavailable. Please try again later.";
      } else if (state === "verified") {
        help.textContent = "Human verification completed for this request.";
      } else if (state === "verification-required") {
        help.textContent = "Complete human verification again before retrying.";
      } else {
        help.textContent = "Complete human verification before submitting.";
      }
    },
  });

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    feedback.textContent = "";
    if (!email.validity.valid || !consent.checked) {
      const state = waitlistStateForResponse(400, { code: "invalid_request" });
      feedback.textContent = state.message;
      email.setAttribute("aria-invalid", String(!email.validity.valid));
      return;
    }
    if (!(await turnstileLifecycle.ready) || turnstileLifecycle.token() === "") {
      feedback.textContent = "Complete the human verification before trying again.";
      return;
    }
    const notice = form.elements.namedItem("noticeVersion");
    if (!(notice instanceof HTMLInputElement)) {
      feedback.textContent = WAITLIST_COPY["reload-required"];
      return;
    }
    let request;
    try {
      request = buildWaitlistRequest({
        email: email.value,
        consentChecked: consent.checked,
        consentNoticeVersion: consent.value,
        renderedNoticeVersion: notice.value,
        turnstileToken: turnstileLifecycle.token(),
      });
    } catch {
      feedback.textContent = WAITLIST_COPY["reload-required"];
      feedback.dataset.state = "reload-required";
      return;
    }

    submit.disabled = true;
    submit.setAttribute("aria-busy", "true");
    feedback.textContent = "Receiving your provisional request…";
    try {
      const response = await fetch(form.action, {
        method: "POST",
        headers: { "Content-Type": "application/json", "Accept": "application/json" },
        body: JSON.stringify(request),
      });
      let body = null;
      try { body = await response.json(); } catch { /* fixed local fallback copy */ }
      const state = waitlistStateForResponse(response.status, body);
      feedback.textContent = state.message;
      feedback.dataset.state = state.kind;
      if (state.kind === "field-error") email.setAttribute("aria-invalid", "true");
    } catch {
      const state = waitlistStateForResponse(503, null);
      feedback.textContent = state.message;
      feedback.dataset.state = state.kind;
    } finally {
      turnstileLifecycle.reset();
      submit.disabled = false;
      submit.removeAttribute("aria-busy");
    }
  });
}

if (typeof document !== "undefined") {
  installDemo();
  installWaitlist();
}
