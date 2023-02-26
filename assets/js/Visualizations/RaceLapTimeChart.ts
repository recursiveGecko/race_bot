import { Chart, ChartConfiguration, ChartDataset, ChartEvent, Color, FontSpec, LegendItem } from 'chart.js/auto';
import { AnnotationOptions } from 'chartjs-plugin-annotation';
import { ChartVisualization } from '.';
import { TrackStatusData, AnyChartData, LapTimeDataPoint, DriverLapTimeData, TrackStatusDataPoint } from './DataPayloads';
import { DataSetUtils } from './DatasetUtils';

class RaceLapTimeChart implements ChartVisualization {
  private chart: Chart;
  private driverData: { [key: number]: LapTimeDataPoint[] } = {};
  private updateTimeout?: number;
  private hideDatasetAfterLeave: Record<number, boolean> = {};

  constructor(private canvas: HTMLCanvasElement) {
    const schema = this.schema();
    this.chart = new Chart(canvas, schema);
  }

  destroy() {
    this.chart.destroy();
  }

  update() {
    if (this.updateTimeout != undefined) {
      return;
    }

    this.updateTimeout = setTimeout(() => {
      this.chart.update();
      this.updateTimeout = undefined;
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
      DataSetUtils.mergeDataset(existingData, data.data, x => x.lap);
    } else {
      const newData = data.data;
      this.driverData[data.driver_number] = newData;

      const dataset: ChartDataset = {
        label: data.driver_abbr,
        data: newData as any,
        order: data.chart_order,
        backgroundColor: `#${data.team_color}`,
        borderColor: `#${data.team_color}`,
        borderDash: data.chart_team_order == 0 ? [] : [15, 2],
      }

      this.chart.data.datasets.push(dataset);
    }

    this.update();
  }

  private updateTrackStatusData(data: TrackStatusData) {
    const trackStatusAnnotations: Record<string, AnnotationOptions> = {};

    for (let point of data.data) {
      let annotation: AnnotationOptions;

      if (point.type === 'interval') {
        annotation = this.makeIntervalAnnotation(point);
      } else {
        annotation = this.makeInstantAnnotation(point);
      }

      trackStatusAnnotations[point.id] = annotation;
    }

    this.chart.options.plugins!.annotation!.annotations =
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

  private handleLegendHover(e: ChartEvent, legendItem: LegendItem) {
    const alpha = '20';

    this.chart.data.datasets.forEach((dataset, index) => {
      this.hideDatasetAfterLeave[index] = !!dataset.hidden;
      const isHoveredDataset = index == legendItem.datasetIndex;

      if (isHoveredDataset) {
        dataset.hidden = false;
        return;
      }

      dataset.borderColor = this.maybeAddAlphaToHex(dataset.borderColor as Color, alpha);
      dataset.backgroundColor = this.maybeAddAlphaToHex(dataset.backgroundColor as Color, alpha);
    })

    this.update();
  }

  private handleLegendLeave(e: ChartEvent, legendItem: LegendItem) {
    this.chart.data.datasets.forEach((dataset, index) => {
      if (this.hideDatasetAfterLeave[index]) {
        dataset.hidden = true;
        delete this.hideDatasetAfterLeave[index];
      }

      dataset.borderColor = this.maybeRemoveAlphaFromHex(dataset.borderColor as Color);
      dataset.backgroundColor = this.maybeRemoveAlphaFromHex(dataset.backgroundColor as Color);
    })

    this.showAllDatasetsIfAllAreHidden();
    this.update();
  }

  private handleLegendClick(e: ChartEvent, legendItem: LegendItem) {
    const clickedDatasetIndex = legendItem.datasetIndex;
    if (clickedDatasetIndex == undefined) return;

    let modifiedKeyPressed = false;

    if (e.native != null) {
      const mouseEvent: MouseEvent = e.native as MouseEvent;
      modifiedKeyPressed = mouseEvent.ctrlKey || mouseEvent.shiftKey || mouseEvent.altKey;
    }

    if (modifiedKeyPressed) {
      // Hide all other datasets
      this.chart.data.datasets.forEach((dataset, index) => {
        dataset.hidden = index !== clickedDatasetIndex;
      });

      this.hideDatasetAfterLeave = {};
      this.update();
    } else {
      this.hideDatasetAfterLeave[clickedDatasetIndex] = !this.hideDatasetAfterLeave[clickedDatasetIndex];
    }
  }

  private showAllDatasetsIfAllAreHidden() {
    const datasets = this.chart.data.datasets;
    const allHidden = datasets.every(dataset => dataset.hidden);
    if (!allHidden) return;

    datasets.forEach(dataset => dataset.hidden = false);
    this.hideDatasetAfterLeave = {};
  }

  private maybeAddAlphaToHex(hex: Color, alpha: string): Color {
    if (typeof hex !== 'string') return hex;
    if (hex.length !== 7) return hex;

    return hex + alpha;
  }

  private maybeRemoveAlphaFromHex(hex: Color): Color {
    if (typeof hex !== 'string') return hex;
    if (hex.length !== 9) return hex;

    return hex.slice(0, 7);
  }

  private schema(): ChartConfiguration {
    const monoFontFamily = 'Menlo, Consolas, Monaco, Liberation Mono, Lucida Console, monospace';
    const scalesTitleFontConfig: Partial<FontSpec> = {
      family: monoFontFamily,
      size: 16,
    };
    const scalesTitleColor = 'black';
    const ticksFontConfig: Partial<FontSpec> = {
      family: monoFontFamily,
      size: 14
    };
    const ticksColor = 'black';

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
        layout: {},
        scales: {
          x: {
            display: true,
            type: 'linear',
            title: {
              display: true,
              text: "Lap",
              font: scalesTitleFontConfig,
              color: scalesTitleColor,
            },
            ticks: {
              precision: 0,
              stepSize: 5,
              font: ticksFontConfig,
              color: ticksColor
            }
          },
          y: {
            display: true,
            type: 'laptime' as any,
            title: {
              display: true,
              text: "Lap Time",
              font: scalesTitleFontConfig,
              color: scalesTitleColor
            },
            ticks: {
              font: ticksFontConfig,
              color: ticksColor
            }
          }
        },
        plugins: {
          legend: {
            onHover: this.handleLegendHover.bind(this),
            onLeave: this.handleLegendLeave.bind(this),
            onClick: this.handleLegendClick.bind(this),
            labels: {
              font: {
                family: monoFontFamily,
                size: 15,
                style: 'normal',
              },
              color: 'rgba(0, 0, 0, 1)',
              boxWidth: 20,
              boxHeight: 15
            },
            maxWidth: 5,
            fullSize: false,

          },
          annotation: {
            annotations: {},
            common: {
              font: {
                family: monoFontFamily
              }
            }
          },
          tooltip: {
            enabled: true,
            // mode: 'x', // shows all lap times for a given lap
            itemSort(a, b, data) {
              return a.parsed.y - b.parsed.y;
            },
            callbacks: {
              title(tooltipItems) {
                const lap = tooltipItems[0].label;
                return `Lap ${lap}`
              }
            },
            bodyFont: {
              family: monoFontFamily
            }
          }
          // zoom: {
          //   zoom: {
          //     mode: 'y',
          //     wheel: {
          //       enabled: true
          //     },
          //     pinch: {
          //       enabled: true
          //     }
          //   },
          //   pan: {
          //     enabled: true,
          //     mode: 'xy',
          //   },
          // }
        }
      },

    };

    return schema;
  }
}

export { RaceLapTimeChart, DriverLapTimeData };