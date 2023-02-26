import {RaceLapTimeChart} from "./RaceLapTimeChart";

class FPQualiLapTimeChart extends RaceLapTimeChart {
  constructor(canvas: HTMLCanvasElement) {
    super(canvas);
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
      },
      ticks: {
        stepSize: 5,
      }
    };

    Object.assign(scales.x, newXScaleOpts);

    delete plugins.tooltip.callbacks.title;
    return schema;
  }
}

export {FPQualiLapTimeChart};