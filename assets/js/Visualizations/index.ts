import {Chart} from 'chart.js/auto';
import 'chartjs-adapter-date-fns';
import annotationPlugin from 'chartjs-plugin-annotation';
import zoomPlugin from 'chartjs-plugin-zoom';

import { RaceLapTimeChart } from "./RaceLapTimeChart"
import { AnyChartData } from './DataPayloads';

Chart.register(annotationPlugin);
Chart.register(zoomPlugin);

interface ChartVisualization {
  updateData(data: AnyChartData): void;
  destroy(): void;
}

interface ConstructableChart {
  new(canvas: HTMLCanvasElement): ChartVisualization;
}

const ChartJsCharts = {
  RaceLapTimeChart,
}

const createChart = (chartType: string, canvas: HTMLCanvasElement): ChartVisualization => {
  const chartClass: ConstructableChart | undefined = ChartJsCharts[chartType];

  if (!chartClass) {
    console.error(`Chart type '${chartType}' not found`);
    return;
  }

  return new chartClass(canvas);
}

export {
  createChart,
  ChartVisualization
};