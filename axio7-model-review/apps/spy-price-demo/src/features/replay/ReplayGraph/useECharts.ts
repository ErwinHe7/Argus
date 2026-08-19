import * as echarts from "echarts";
import type { EChartsOption, EChartsType } from "echarts";
import { useEffect, useRef } from "react";
import type { RefObject } from "react";

export function useECharts(
  option: EChartsOption,
): RefObject<HTMLDivElement | null> {
  const containerRef = useRef<HTMLDivElement>(null);
  const chartRef = useRef<EChartsType | null>(null);

  useEffect(() => {
    const container = containerRef.current;
    if (container === null) {
      return;
    }

    const chart = echarts.init(container, undefined, { renderer: "svg" });
    const resizeObserver = new ResizeObserver(() => {
      chart.resize();
    });

    chartRef.current = chart;
    resizeObserver.observe(container);

    return () => {
      resizeObserver.disconnect();
      chart.dispose();
      chartRef.current = null;
    };
  }, []);

  useEffect(() => {
    chartRef.current?.setOption(option, {
      notMerge: true,
      lazyUpdate: false,
    });
  }, [option]);

  return containerRef;
}
