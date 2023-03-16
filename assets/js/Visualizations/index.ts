import { Chart } from 'chart.js/auto';
import 'chartjs-adapter-date-fns';
import annotationPlugin from 'chartjs-plugin-annotation';
// import zoomPlugin from 'chartjs-plugin-zoom';

import { RaceLapTimeChart } from "./RaceLapTimeChart"
import { LapTimeScale } from './LapTimeScale';
import { AnyChartData } from './DataPayloads';
import { FPQualiLapTimeChart } from "./FPQualiLapTimeChart";

// Chart.register(zoomPlugin);
Chart.register(annotationPlugin);
Chart.register(LapTimeScale);

interface ChartVisualization {
  updateData(data: AnyChartData): void;

  destroy(): void;
}

interface ConstructableChart {
  new(canvas: HTMLCanvasElement): ChartVisualization;
}

const ChartJsCharts: Record<string, ConstructableChart> = {
  RaceLapTimeChart,
  FPQualiLapTimeChart,
}

const createChart = (chartType: string, canvas: HTMLCanvasElement): ChartVisualization => {
  const chartClass: ConstructableChart | undefined = ChartJsCharts[chartType];

  if (!chartClass) {
    throw new Error(`Chart type '${chartType}' not found`);
  }

  return new chartClass(canvas);
}

export {
  createChart,
  ChartVisualization
};