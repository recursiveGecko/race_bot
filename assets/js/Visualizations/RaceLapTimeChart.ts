import { Chart, ChartConfiguration, ChartDataset, LegendElement, LegendItem } from 'chart.js/auto';
import { ChartEvent } from 'chart.js/dist/core/core.plugins';
import { AnnotationOptions } from 'chartjs-plugin-annotation';
import { ChartVisualization } from '.';
import { TrackStatusData, AnyChartData, LapTimeDataPoint, DriverLapTimeData, TrackStatusDataPoint } from './DataPayloads';

class RaceLapTimeChart implements ChartVisualization {
  private chart: Chart;
  private driverData: { [key: number]: LapTimeDataPoint[] } = {};
  private updateTimeout?: number = null;

  constructor(private canvas: HTMLCanvasElement) {

    const schema = this.schema();
    this.chart = new Chart(canvas, schema);
  }

  destroy() {
    this.chart.destroy();
  }

  update() {
    if (this.updateTimeout != null) {
      return;
    }

    this.updateTimeout = setTimeout(() => {
      this.chart.update();
      this.updateTimeout = null;
    }, 10);
  }

  updateData(data: AnyChartData) {
    if (data.op == 'insert') {
      console.warn(`Insert not implemented for ${this.constructor.name}`);
      return;
    }

    if (data.dataset === 'driver_data') {
      this.updateDriverData(data as DriverLapTimeData);
    } else if (data.dataset === 'track_data') {
      this.updateTrackStatusData(data as TrackStatusData);
    } else {
      console.warn(`Unknown dataset for ${this.constructor.name}`, data);
    }
  }

  private updateDriverData(data: DriverLapTimeData) {
    const existingData = this.driverData[data.driver_number];

    if (existingData) {
      existingData.splice(0, existingData.length);
      existingData.push(...data.data);
    } else {
      const newData = data.data;
      this.driverData[data.driver_number] = newData;

      const dataset: ChartDataset = {
        label: data.driver_abbr,
        data: newData as any,
        backgroundColor: `#${data.team_color}`,
        borderColor: `#${data.team_color}`,
        borderDash: data.use_primary_color ? [] : [15, 2],
      }

      this.chart.data.datasets.push(dataset);
    }

    this.update();
  }

  private updateTrackStatusData(data: TrackStatusData) {
    const trackStatusAnnotations = {};

    for (let point of data.data) {
      let annotation: AnnotationOptions;

      if (point.type === 'interval') {
        annotation = this.makeIntervalAnnotation(point);
      } else {
        annotation = this.makeInstantAnnotation(point);
      }

      trackStatusAnnotations[point.id] = annotation;
    }

    this.chart.options.plugins.annotation.annotations =
      trackStatusAnnotations;

    this.update();
  }

  private makeIntervalAnnotation(point: TrackStatusDataPoint): AnnotationOptions {
    return {
      type: 'box',
      xMin: point.lap_from,
      xMax: point.lap_to,
      backgroundColor: 'rgba(255, 230, 0, 0.25)',
      borderColor: 'rgba(255, 150, 0, 0.25)',
      borderRadius: 2,
      borderWidth: 2,
      drawTime: 'beforeDatasetsDraw',
      label: {
        display: true,
        content: point.status,
        drawTime: 'afterDraw',
        color: 'rgba(100, 100, 100, 1)',
        position: {
          x: 'center',
          y: 'start'
        }
      }
    }
  }

  private makeInstantAnnotation(point: TrackStatusDataPoint): AnnotationOptions {
    return {
      type: 'line',
      xMin: point.lap_from,
      xMax: point.lap_from,
      borderColor: 'rgba(255, 0, 0, 1)',
      borderWidth: 2,
      drawTime: 'beforeDatasetsDraw',
      label: {
        display: true,
        content: point.status,
        drawTime: 'afterDraw',
        position: 'start',
      }
    }
  }

  private handleHover(e: ChartEvent, legendItem: LegendItem) {
    const alpha = '20';

    this.chart.data.datasets.forEach((dataset, index) => {
      const isHoveredDataset = index == legendItem.datasetIndex;
      if (isHoveredDataset) return;

      dataset.borderColor = this.maybeAddAlphaToHex(dataset.borderColor as string, alpha);
      dataset.backgroundColor = this.maybeAddAlphaToHex(dataset.backgroundColor as string, alpha);
    })

    this.update();
  }

  private handleLeave(e: ChartEvent, legendItem: LegendItem) {
    this.chart.data.datasets.forEach((dataset, index) => {
      dataset.borderColor = this.maybeRemoveAlphaFromHex(dataset.borderColor as string);
      dataset.backgroundColor = this.maybeRemoveAlphaFromHex(dataset.backgroundColor as string);
    })

    this.update();
  }

  private maybeAddAlphaToHex(hex: string, alpha: string) {
    if (hex.length == 7) {
      return hex + alpha;
    } else {
      return hex;
    }
  }

  private maybeRemoveAlphaFromHex(hex: string) {
    if (hex.length == 9) {
      return hex.slice(0, 7);
    } else {
      return hex;
    }
  }

  private schema(): ChartConfiguration {
    const schema: ChartConfiguration = {
      type: 'line',
      data: {
        datasets: []
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        parsing: {
          xAxisKey: 'lap',
          yAxisKey: 't',
        },
        scales: {
          x: { 
            display: true, 
            type: 'linear',
            title: {
              display: true,
              text: "Lap"
            }
          },
          y: {
            display: true,
            type: 'time',
            time: {
              unit: 'millisecond',
              displayFormats: {
                millisecond: 'm:ss.SS'
              },
              tooltipFormat: 'm:ss.SS'
            },
            ticks: {
              stepSize: 1000
            },
            title: {
              display: true,
              text: "Lap time"
            }
          }
        },
        plugins: {
          legend: {
            onHover: this.handleHover.bind(this),
            onLeave: this.handleLeave.bind(this),
          },
          annotation: {
            annotations: {}
          },
          zoom: {
            zoom: {
              mode: 'y',
              wheel: {
                enabled: true
              },
              pinch: {
                enabled: true
              }
            },
            pan: {
              enabled: true,
              mode: 'xy',
            },
          }
        }
      },

    };

    return schema;
  }
}

export { RaceLapTimeChart, DriverLapTimeData };