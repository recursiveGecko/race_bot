import { Chart, ChartConfiguration, ChartDataset, ChartEvent, Color, FontSpec, LegendItem } from 'chart.js/auto';
import { AnnotationOptions } from 'chartjs-plugin-annotation';
import { ChartVisualization } from '.';
import { TrackStatusData, AnyChartData, LapTimeDataPoint, DriverLapTimeData, TrackStatusDataPoint } from './DataPayloads';
import { DataSetUtils } from './DatasetUtils';
import { Storage } from "@assets/Storage";
import { DarkModeObserver } from '@assets/DarkModeObserver';

const isDark = DarkModeObserver.isDarkModeEnabled.bind(DarkModeObserver);
const darkModeText = 'hsl(220,10%,90%)';
const lightModeText = 'hsl(0,0%,5%)';

class RaceLapTimeChart implements ChartVisualization {
  protected chart: Chart;
  protected driverData: { [key: number]: ChartDataset } = {};
  protected updateTimeout?: number;
  protected hideDatasetAfterLeave: Record<number, boolean> = {};
  protected darkModeListener: EventListener = () => this.update();

  constructor(protected canvas: HTMLCanvasElement) {
    const schema = this.schema();
    this.chart = new Chart(canvas, schema);
    DarkModeObserver.subscribe(this.darkModeListener);
  }

  destroy() {
    DarkModeObserver.unsubscribe(this.darkModeListener);
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

  /**
   * Sorts the data by lap number, ascending so that the lines 
   * are drawn in the correct order.
   */
  protected sortDataAsc(data: DriverLapTimeData) {
    data.data.sort((a, b) => a.lap - b.lap);
  }

  protected updateDriverData(data: DriverLapTimeData) {
    this.sortDataAsc(data);

    const existingDataset = this.driverData[data.driver_number];

    if (existingDataset) {
      const existingData = existingDataset.data as unknown as LapTimeDataPoint[];

      DataSetUtils.mergeDataset(existingData, data.data, x => x.lap);
      existingDataset.order = data.chart_order;
    } else {
      const newData = data.data;

      const dataset: ChartDataset = {
        label: data.driver_abbr,
        data: newData as any,
        order: data.chart_order,
        hidden: !this.loadDriverVisibility(data.driver_abbr),
        backgroundColor: `#${data.team_color}`,
        borderColor: `#${data.team_color}`,
        borderDash: data.chart_team_order == 0 ? [] : [15, 2],
      }

      this.driverData[data.driver_number] = dataset;
      this.chart.data.datasets.push(dataset);
    }

    this.update();
  }

  protected updateTrackStatusData(data: TrackStatusData) {
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

  protected makeIntervalAnnotation(point: TrackStatusDataPoint): AnnotationOptions {
    const backgroundColor = () => isDark() ? 'hsla(54, 100%, 30%, 0.3)' : 'rgba(255, 230, 0, 0.4)';
    const borderColor = () => isDark() ? 'rgba(0,0,0,0)' : 'rgba(0,0,0,0)';
    const labelColor = () => isDark() ? 'white' : 'black';

    let rotation = 0;

    if (point.lap_to && point.lap_from && (point.lap_to - point.lap_from) < 2) {
      rotation = -90;
    }

    return {
      type: 'box',
      xMin: point.lap_from,
      xMax: point.lap_to,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      borderRadius: 2,
      borderWidth: 2,
      drawTime: 'beforeDatasetsDraw',
      label: {
        display: true,
        content: point.status,
        color: labelColor,
        rotation: rotation,
        position: {
          x: 'center',
          y: 'start'
        },
        drawTime: 'afterDatasetsDraw',
      }
    }
  }

  protected makeInstantAnnotation(point: TrackStatusDataPoint): AnnotationOptions {
    const borderColor = () => isDark() ? 'red' : 'red';
    const labelColor = () => isDark() ? 'white' : 'black';
    const labelBorderColor = () => isDark() ? 'red' : 'red';
    const labelBackgroundColor = () => isDark() ? 'black' : 'white';

    return {
      type: 'line',
      xMin: point.lap_from,
      xMax: point.lap_from,
      borderColor: borderColor,
      borderWidth: 2,
      drawTime: 'beforeDatasetsDraw',
      label: {
        display: true,
        content: point.status,
        backgroundColor: labelBackgroundColor,
        borderColor: labelBorderColor,
        borderWidth: 1,
        color: labelColor,
        position: 'start',
        drawTime: 'afterDatasetsDraw',
      },
    }
  }

  protected handleLegendHover(e: ChartEvent, legendItem: LegendItem) {
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

  protected handleLegendLeave(e: ChartEvent, legendItem: LegendItem) {
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

  protected handleLegendClick(e: ChartEvent, legendItem: LegendItem) {
    const datasets = this.chart.data.datasets;
    const clickedDatasetIndex = legendItem.datasetIndex;
    if (clickedDatasetIndex == undefined) return;

    let modifiedKeyPressed = false;

    if (e.native != null) {
      const mouseEvent: MouseEvent = e.native as MouseEvent;
      modifiedKeyPressed = mouseEvent.shiftKey;
    }

    if (modifiedKeyPressed) {
      const numShown = datasets.filter(x => !x.hidden).length

      if (numShown == 1) {
        // Show all other datasets
        datasets.forEach((dataset) => {
          dataset.hidden = false;
        });
      } else {
        // Hide all other datasets
        datasets.forEach((dataset, index) => {
          dataset.hidden = index !== clickedDatasetIndex;
        });
      }

      this.hideDatasetAfterLeave = {};
      this.update();
    } else {
      this.hideDatasetAfterLeave[clickedDatasetIndex] = !this.hideDatasetAfterLeave[clickedDatasetIndex];
    }

    this.saveSelectedDrivers();
  }

  protected showAllDatasetsIfAllAreHidden() {
    const datasets = this.chart.data.datasets;
    const allHidden = datasets.every(dataset => dataset.hidden);
    if (!allHidden) return;

    datasets.forEach(dataset => dataset.hidden = false);
    this.hideDatasetAfterLeave = {};

    this.saveSelectedDrivers();
  }

  protected maybeAddAlphaToHex(hex: Color, alpha: string): Color {
    if (typeof hex !== 'string') return hex;
    if (hex.length !== 7) return hex;

    return hex + alpha;
  }

  protected maybeRemoveAlphaFromHex(hex: Color): Color {
    if (typeof hex !== 'string') return hex;
    if (hex.length !== 9) return hex;

    return hex.slice(0, 7);
  }

  protected saveSelectedDrivers() {
    this.chart.data.datasets.forEach((dataset, index) => {
      const isHidden = dataset.hidden;
      const hideAfterLeave = this.hideDatasetAfterLeave[index];

      const prefersVisibility = !isHidden && !hideAfterLeave;
      this.saveDriverVisibility(dataset.label!, prefersVisibility)
    })
  }

  private saveDriverVisibility(driverAbbr: string, state: boolean) {
    const value = state ? 1 : 0;
    Storage.save(`chart:display-driver:${driverAbbr}`, value)
  }

  private loadDriverVisibility(driverAbbr: string) {
    const state = Storage.load(`chart:display-driver:${driverAbbr}`, 1, parseInt);
    return state !== 0;
  }

  protected schema() {
    const monoFontFamily = 'Menlo, Consolas, Monaco, Liberation Mono, Lucida Console, monospace';
    const scalesTitleFontConfig: Partial<FontSpec> = {
      family: monoFontFamily,
      size: 16,
    };
    const ticksFontConfig: Partial<FontSpec> = {
      family: monoFontFamily,
      size: 14
    };

    const scalesTitleColor = () => isDark() ? darkModeText : lightModeText;
    const ticksColor = () => isDark() ? darkModeText : lightModeText;
    const legendColor = () => isDark() ? darkModeText : lightModeText;
    const gridColor = () => isDark() ? 'hsl(220,10%,20%)' : 'rgba(0,0,0,0.1)';

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
          yAxisKey: 't'
        },
        animation: false,
        layout: {
        },
        scales: {
          x: {
            display: true,
            type: 'linear',
            title: {
              display: true,
              text: "Lap",
              font: scalesTitleFontConfig,
              color: scalesTitleColor as any,
              padding: 0
            },
            ticks: {
              precision: 0,
              stepSize: 5,
              font: ticksFontConfig,
              color: ticksColor,
              padding: 0
            },
            grid: {
              color: gridColor as any,
            }
          },
          y: {
            display: true,
            type: 'laptime' as any,
            title: {
              display: true,
              text: "Lap Time",
              font: scalesTitleFontConfig,
              color: scalesTitleColor as any,
              padding: {
                top: 0
              }
            },
            ticks: {
              font: ticksFontConfig,
              color: ticksColor,
            },
            grid: {
              color: gridColor as any
            }
          },
        },
        plugins: {
          legend: {
            display: true,
            onHover: this.handleLegendHover.bind(this),
            onLeave: this.handleLegendLeave.bind(this),
            onClick: this.handleLegendClick.bind(this),
            labels: {
              font: {
                family: monoFontFamily,
                size: 15,
                style: 'normal',
              },
              color: legendColor as any,
              boxWidth: 20,
              boxHeight: 15,
            },
          },
          annotation: {
            annotations: {},
            common: {
              font: {
                family: monoFontFamily
              },
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
        }
      },
    };

    return schema;
  }
}

export { RaceLapTimeChart };