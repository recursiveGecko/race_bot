import { AnnotationOptions } from "chartjs-plugin-annotation";
import { TrackStatusDataPoint } from "./DataPayloads";
import { RaceLapTimeChart } from "./RaceLapTimeChart";

class FPQualiLapTimeChart extends RaceLapTimeChart {
  constructor(canvas: HTMLCanvasElement) {
    super(canvas);
  }

  protected makeIntervalAnnotation(point: TrackStatusDataPoint): AnnotationOptions {
    const options = super.makeIntervalAnnotation(point);
    options.xMin = point.ts_from;
    options.xMax = point.ts_to;
    return options;
  }

  protected makeInstantAnnotation(point: TrackStatusDataPoint): AnnotationOptions {
    const options = super.makeIntervalAnnotation(point);
    options.xMin = point.ts_from;
    options.xMax = point.ts_to;
    return options;
  }

  protected schema() {
    const schema = super.schema() as any;
    const scales = schema.options.scales;
    const plugins = schema.options.plugins;

    schema.options.parsing.xAxisKey = 'ts';
    scales.x.title.text = 'Session Time';

    const newXScaleOpts = {
      type: 'time',
      display: true,
      time: {
        unit: 'minute',
        displayFormats: {
          minute: 'H:mm',
        },
        tooltipFormat: 'H:mm:ss'
      }
    };

    Object.assign(scales.x, newXScaleOpts);

    delete plugins.tooltip.callbacks.title;
    delete scales.x.ticks.stepSize;
    delete scales.x.ticks.precision;

    return schema;
  }
}

export { FPQualiLapTimeChart };