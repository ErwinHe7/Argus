import "@testing-library/jest-dom/vitest";

const values = new Map<string, string>();
const storage: Storage = {
  get length() {
    return values.size;
  },
  clear: () => values.clear(),
  getItem: (key) => values.get(key) ?? null,
  key: (index) => Array.from(values.keys())[index] ?? null,
  removeItem: (key) => values.delete(key),
  setItem: (key, value) => values.set(key, value),
};
Object.defineProperty(window, "localStorage", {
  configurable: true,
  value: storage,
});

class TestResizeObserver implements ResizeObserver {
  readonly disconnect = vi.fn();
  readonly observe = vi.fn();
  readonly unobserve = vi.fn();

  constructor(_callback: ResizeObserverCallback) {}

  takeRecords(): ResizeObserverEntry[] {
    return [];
  }
}

Object.defineProperty(globalThis, "ResizeObserver", {
  configurable: true,
  value: TestResizeObserver,
});
