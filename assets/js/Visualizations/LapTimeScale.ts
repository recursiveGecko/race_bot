import {Scale, Tick} from "chart.js";

class LapTimeScale extends Scale {
  static id = 'laptime';
  static step = 1000;

  constructor(cfg: any) {
    super(cfg)
  }

  determineDataLimits() {
    const {min, max} = this.getMinMax(false);
    this.min = min;
    this.max = max;
  }

  buildTicks(): Tick[] {
    const step = LapTimeScale.step;
    const roundedMin = this.roundToMs(this.min, step, Math.ceil);
    const roundedMax = this.roundToMs(this.max, step, Math.floor);

    const ticks: Tick[] = [];
    for (let x = roundedMin; x <= roundedMax; x += step) {
      ticks.push({
        value: x,
        major: false
      })
    }
    return ticks;
  }

  getLabelForValue(value: number): string {
    return this.formatMs(value, 3);
  }

  getPixelForValue(value: number, index?: number): number {
    const pos = this.getDecimalForValue(value)
    return this.getPixelForDecimal(pos)
  }

  generateTickLabels(ticks: Tick[]) {
    for (const tick of ticks) {
      tick.label = this.formatMs(tick.value, 0);
    }
  }

  private getDecimalForValue(value) {
    return value === null ? NaN : (value - this.min) / (this.max - this.min);
  }

  private roundToMs(value: number, ms: number, roundFn: (x: number) => number) {
    return roundFn(value / ms) * ms;
  }

  private formatMs(value: number | unknown, msPrecision: number) {
    if (typeof value !== 'number') return '';

    const milliseconds = value % 1000;
    const totalSeconds = (value - milliseconds) / 1000;
    const seconds = totalSeconds % 60;
    const minutes = (totalSeconds - seconds) / 60;

    const fmtSec = seconds.toString().padStart(2, '0');


    if (msPrecision <= 0) {
      return `${minutes}:${fmtSec}`;
    } else {
      const fmtMs = milliseconds.toString().padStart(msPrecision, '0').slice(0, msPrecision);
      return `${minutes}:${fmtSec}.${fmtMs}`;
    }
  }
}

export {LapTimeScale}