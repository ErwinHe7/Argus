import { describe, expect, it, vi } from "vitest";

import {
  buildWaitlistRequest,
  createDemoLifecycle,
  createTurnstileLifecycle,
  waitlistStateForResponse,
} from "../public/landing.js";

const configuration = {
  environment: "production" as const,
  demoOrigin: "https://demo.just-build-this.app",
  protocols: [2, 1] as const,
};

function readyEvent(overrides: Record<string, unknown> = {}) {
  const frameWindow = { name: "current-frame" };
  return {
    frameWindow,
    event: {
      origin: configuration.demoOrigin,
      source: frameWindow,
      data: {
        source: "ritual-investing-demo",
        type: "ritual-demo-ready",
        protocolVersion: 2,
        environment: "production",
        attemptId: "attempt-1",
        ...overrides,
      },
    },
  };
}

describe("embedded demo lifecycle", () => {
  it("accepts only a compatible current-frame message from the exact pairwise peer", () => {
    const { event, frameWindow } = readyEvent();
    const updates: Array<{ state: string; message: string }> = [];
    const lifecycle = createDemoLifecycle({
      configuration,
      createAttemptId: () => "attempt-1",
      createFrame: (url: string) => ({ node: { url }, sourceWindow: frameWindow }),
      replaceFrame: () => undefined,
      scheduleTimeout: () => 7,
      cancelTimeout: () => undefined,
      update: (state: { state: string; message: string }) => updates.push(state),
    });

    expect(lifecycle.receiveMessage(event)).toBe(true);
    expect(updates.at(-1)).toMatchObject({ state: "ready" });
  });

  it.each([
    ["null payload", { data: null }],
    ["hostile string", { data: "ritual-demo-ready" }],
    ["wrong origin", { origin: "https://hostile.example" }],
    ["wrong source window", { source: { name: "stale-frame" } }],
    ["missing source marker", { data: { type: "ritual-demo-ready", protocolVersion: 2, environment: "production", attemptId: "attempt-1" } }],
    ["stale attempt", { data: { source: "ritual-investing-demo", type: "ritual-demo-ready", protocolVersion: 2, environment: "production", attemptId: "attempt-0" } }],
    ["cross environment", { data: { source: "ritual-investing-demo", type: "ritual-demo-ready", protocolVersion: 2, environment: "beta", attemptId: "attempt-1" } }],
    ["later protocol", { data: { source: "ritual-investing-demo", type: "ritual-demo-ready", protocolVersion: 3, environment: "production", attemptId: "attempt-1" } }],
    ["malformed protocol", { data: { source: "ritual-investing-demo", type: "ritual-demo-ready", protocolVersion: "2", environment: "production", attemptId: "attempt-1" } }],
    ["unknown type", { data: { source: "ritual-investing-demo", type: "ritual-demo-detail", protocolVersion: 2, environment: "production", attemptId: "attempt-1" } }],
  ])("ignores %s", (_name, mutation) => {
    const { event, frameWindow } = readyEvent();
    const lifecycle = createDemoLifecycle({
      configuration,
      createAttemptId: () => "attempt-1",
      createFrame: (url: string) => ({ node: { url }, sourceWindow: frameWindow }),
      replaceFrame: () => undefined,
      scheduleTimeout: () => 7,
      cancelTimeout: () => undefined,
      update: () => undefined,
    });
    expect(lifecycle.receiveMessage({ ...event, ...mutation })).toBe(false);
  });

  it("replaces the iframe with a fresh attempt on retry and reset", () => {
    const attempts = ["attempt-1", "attempt-2", "attempt-3"];
    const frames: Array<{ url: string; identity: object }> = [];
    const lifecycle = createDemoLifecycle({
      configuration,
      createAttemptId: () => attempts.shift()!,
      createFrame: (url: string) => ({ node: { url, identity: {} }, sourceWindow: {} }),
      replaceFrame: (frame: { url: string; identity: object }) => frames.push(frame),
      scheduleTimeout: () => 7,
      cancelTimeout: () => undefined,
      update: () => undefined,
    });

    const first = frames[0]!;
    lifecycle.retry();
    const second = frames[1]!;
    lifecycle.reset();
    const third = frames[2]!;

    expect(new Set(frames.map((frame) => frame.identity)).size).toBe(3);
    expect([first.url, second.url, third.url]).toEqual([
      "https://demo.just-build-this.app/?environment=production&attempt=attempt-1",
      "https://demo.just-build-this.app/?environment=production&attempt=attempt-2",
      "https://demo.just-build-this.app/?environment=production&attempt=attempt-3",
    ]);
  });

  it("exposes retry after timeout while stale timeout callbacks cannot replace current state", () => {
    const callbacks: Array<() => void> = [];
    const updates: Array<{ state: string; retryVisible: boolean }> = [];
    const lifecycle = createDemoLifecycle({
      configuration,
      createAttemptId: vi.fn().mockReturnValueOnce("attempt-1").mockReturnValueOnce("attempt-2"),
      createFrame: (url: string) => ({ node: { url }, sourceWindow: {} }),
      replaceFrame: () => undefined,
      scheduleTimeout: (callback: () => void) => (callbacks.push(callback), callbacks.length),
      cancelTimeout: () => undefined,
      update: (state: { state: string; retryVisible: boolean }) => updates.push(state),
    });

    lifecycle.retry();
    callbacks[0]!();
    expect(updates.at(-1)).toMatchObject({ state: "loading", retryVisible: false });
    callbacks[1]!();
    expect(updates.at(-1)).toMatchObject({ state: "timed-out", retryVisible: true });
  });
});

describe("waitlist response presentation", () => {
  it("renders the pairwise widget explicitly and clears single-use tokens on expiry or reset", async () => {
    let options: Record<string, unknown> | undefined;
    const api = {
      render: vi.fn((_target: unknown, configured: Record<string, unknown>) => {
        options = configured;
        return "widget-1";
      }),
      reset: vi.fn(),
    };
    const states: string[] = [];
    const lifecycle = createTurnstileLifecycle({
      target: {},
      siteKey: "synthetic-site-key",
      load: async () => api,
      update: (state: string) => states.push(state),
    });

    await expect(lifecycle.ready).resolves.toBe(true);
    expect(api.render).toHaveBeenCalledOnce();
    expect(options).toMatchObject({ sitekey: "synthetic-site-key", action: "waitlist" });
    expect(options).not.toHaveProperty("remoteip");
    (options?.callback as (token: string) => void)("first-single-use-token");
    expect(lifecycle.token()).toBe("first-single-use-token");
    (options?.["expired-callback"] as () => void)();
    expect(lifecycle.token()).toBe("");
    expect(states.at(-1)).toBe("verification-required");

    (options?.callback as (token: string) => void)("second-single-use-token");
    lifecycle.reset();
    expect(lifecycle.token()).toBe("");
    expect(api.reset).toHaveBeenCalledWith("widget-1");
  });

  it("fails the widget closed until an environment-specific public site key is injected", async () => {
    const load = vi.fn();
    const states: string[] = [];
    const lifecycle = createTurnstileLifecycle({
      target: {},
      siteKey: "",
      load,
      update: (state: string) => states.push(state),
    });
    await expect(lifecycle.ready).resolves.toBe(false);
    expect(load).not.toHaveBeenCalled();
    expect(states).toEqual(["unavailable"]);
  });

  it("binds the request notice to the rendered checked consent value", () => {
    expect(buildWaitlistRequest({
      email: "  Visitor@Example.com ",
      consentChecked: true,
      consentNoticeVersion: "waitlist-v1-2026-08-25",
      renderedNoticeVersion: "waitlist-v1-2026-08-25",
      turnstileToken: "synthetic-token",
    })).toEqual({
      email: "  Visitor@Example.com ",
      consent: true,
      noticeVersion: "waitlist-v1-2026-08-25",
      turnstileToken: "synthetic-token",
    });
  });

  it("refuses a request when rendered notice and consent values drift", () => {
    expect(() => buildWaitlistRequest({
      email: "visitor@example.com",
      consentChecked: true,
      consentNoticeVersion: "waitlist-v1-2026-08-25",
      renderedNoticeVersion: "waitlist-v2",
      turnstileToken: "synthetic-token",
    })).toThrow(/notice/i);
  });

  it.each([
    [202, { code: "accepted" }, "success"],
    [400, { code: "invalid_email" }, "field-error"],
    [409, { code: "stale_notice" }, "reload-required"],
    [429, { code: "rate_limited" }, "retryable"],
    [503, { code: "dependency_unavailable" }, "retryable"],
    [418, { message: "render this hostile string" }, "retryable"],
  ])("maps %i to fixed local state", (status, body, expected) => {
    const state = waitlistStateForResponse(status, body);
    expect(state.kind).toBe(expected);
    expect(state.message).not.toContain("hostile");
    if (expected === "success") {
      expect(state.message).toContain("not verified");
      expect(state.message).toContain("no message has been sent");
    }
  });
});
