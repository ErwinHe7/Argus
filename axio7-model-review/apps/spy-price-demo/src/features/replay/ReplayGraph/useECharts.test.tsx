import { render } from "@testing-library/react";
import type { EChartsOption } from "echarts";
import type { JSX } from "react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { useECharts } from "./useECharts";

const chartSpies = vi.hoisted(() => ({
  clear: vi.fn(),
  dispose: vi.fn(),
  init: vi.fn(),
  resize: vi.fn(),
  setOption: vi.fn(),
}));

vi.mock("echarts", () => ({
  init: chartSpies.init,
}));

class ResizeObserverDouble implements ResizeObserver {
  static instances: ResizeObserverDouble[] = [];

  readonly callback: ResizeObserverCallback;
  readonly disconnect = vi.fn();
  readonly observe = vi.fn();
  readonly unobserve = vi.fn();

  constructor(callback: ResizeObserverCallback) {
    this.callback = callback;
    ResizeObserverDouble.instances.push(this);
  }

  takeRecords(): ResizeObserverEntry[] {
    return [];
  }

  fire(): void {
    this.callback([], this);
  }
}

function ChartHarness({ option }: { option: EChartsOption }): JSX.Element {
  const chartRef = useECharts(option);
  return <div data-testid="chart" ref={chartRef} />;
}

function makeOption(backgroundColor: string): EChartsOption {
  return {
    animation: false,
    animationDuration: 0,
    animationDurationUpdate: 0,
    backgroundColor,
  };
}

beforeEach(() => {
  ResizeObserverDouble.instances = [];
  vi.stubGlobal("ResizeObserver", ResizeObserverDouble);
  chartSpies.clear.mockReset();
  chartSpies.dispose.mockReset();
  chartSpies.init.mockReset();
  chartSpies.resize.mockReset();
  chartSpies.setOption.mockReset();
  chartSpies.init.mockReturnValue({
    clear: chartSpies.clear,
    dispose: chartSpies.dispose,
    resize: chartSpies.resize,
    setOption: chartSpies.setOption,
  });
});

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("useECharts", () => {
  it("initializes one SVG chart and replaces options without clearing it", () => {
    const firstOption = makeOption("#ffffff");
    const secondOption = makeOption("#000000");
    const view = render(<ChartHarness option={firstOption} />);
    const chartElement = view.getByTestId("chart");

    expect(chartSpies.init).toHaveBeenCalledWith(chartElement, undefined, {
      renderer: "svg",
    });
    expect(chartSpies.setOption).toHaveBeenLastCalledWith(firstOption, {
      notMerge: true,
      lazyUpdate: false,
    });

    view.rerender(<ChartHarness option={secondOption} />);

    expect(chartSpies.init).toHaveBeenCalledTimes(1);
    expect(chartSpies.setOption).toHaveBeenLastCalledWith(secondOption, {
      notMerge: true,
      lazyUpdate: false,
    });
    expect(chartSpies.clear).not.toHaveBeenCalled();
  });

  it("snaps resize notifications and disposes chart resources on unmount", () => {
    const view = render(<ChartHarness option={makeOption("#ffffff")} />);
    const observer = ResizeObserverDouble.instances[0];

    expect(observer).toBeDefined();
    expect(observer?.observe).toHaveBeenCalledWith(view.getByTestId("chart"));

    observer?.fire();
    expect(chartSpies.resize).toHaveBeenCalledTimes(1);

    view.unmount();
    expect(observer?.disconnect).toHaveBeenCalledTimes(1);
    expect(chartSpies.dispose).toHaveBeenCalledTimes(1);
  });
});
