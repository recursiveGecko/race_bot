type TrackStatusDataPoint = {
  id: string;
  ts_from?: number,
  ts_to?: number,
  lap_from?: number,
  lap_to?: number,
  status: string,
  type: 'instant' | 'interval'
}

interface TrackStatusData {
  dataset: 'driver_data';
  op: 'insert' | 'replace';
  data: TrackStatusDataPoint[];
}

type LapTimeDataPoint = { lap: number, t: number, ts: number };

interface DriverLapTimeData {
  dataset: 'driver_data';
  op: 'insert' | 'replace';
  driver_number: number;
  driver_name: string;
  driver_abbr: string;
  team_color: string;
  use_primary_color: boolean;
  data: LapTimeDataPoint[];
}

interface AnyChartData {
  dataset: string;
  op: 'insert' | 'replace';
}

export { TrackStatusData, TrackStatusDataPoint, AnyChartData, DriverLapTimeData, LapTimeDataPoint };