defmodule F1Bot.F1Session.DriverDataRepo.Laps do
  @moduledoc """
  Stores all information about laps driven by a driver in the current session,
  e.g. lap number, lap time and timestamp.
  """
  use TypedStruct
  require Logger

  alias F1Bot.F1Session.LiveTimingHandlers.TimingData
  alias F1Bot.F1Session.DriverDataRepo.{Lap, Sector, PersonalBestStats}

  @max_data_fill_delay_ms 15_000
  @outlier_window_ms 60_000 * 2

  typedstruct do
    field(:data, %{pos_integer() => Lap.t()}, default: %{})
  end

  def new() do
    %__MODULE__{}
  end

  def fetch_by_number(laps, lap_no) do
    case Enum.find(laps.data, fn l -> l.number == lap_no end) do
      nil -> {:error, :not_found}
      lap -> {:ok, lap}
    end
  end

  def fastest(%__MODULE__{data: data}) do
    lap =
      data
      |> Stream.filter(fn lap -> lap.time != nil end)
      |> Enum.min_by(fn lap -> Timex.Duration.to_milliseconds(lap.time) end, fn -> nil end)

    case lap do
      nil -> {:error, :no_laps}
      _ -> {:ok, lap}
    end
  end

  def personal_best_stats(%__MODULE__{data: data}) do
    laps =
      data
      |> Map.values()
      |> Stream.filter(fn lap -> lap.is_valid and not lap.is_deleted end)

    acc = %{
      lap_time: nil,
      s1_time: nil,
      s2_time: nil,
      s3_time: nil,
      top_speed: nil
    }

    acc =
      Enum.reduce(laps, acc, fn lap, acc ->
        s = lap.sectors
        is_complete = lap.timestamp != nil

        new_top_speed =
          if is_complete do
            max_val(acc.top_speed, lap.top_speed)
          else
            acc.top_speed
          end

        %{
          lap_time: min_time(acc.lap_time, lap.time),
          s1_time: if(!!s[1], do: min_time(acc.s1_time, s[1].time), else: acc.s1_time),
          s2_time: if(!!s[2], do: min_time(acc.s2_time, s[2].time), else: acc.s2_time),
          s3_time: if(!!s[3], do: min_time(acc.s3_time, s[3].time), else: acc.s3_time),
          top_speed: new_top_speed
        }
      end)

    %PersonalBestStats{
      lap_time_ms: acc.lap_time,
      sectors_ms: %{
        1 => acc.s1_time,
        2 => acc.s2_time,
        3 => acc.s3_time
      },
      top_speed: acc.top_speed
    }
  end

  def push_timing_data(
        self = %__MODULE__{},
        current_lap_number,
        timing_data = %TimingData{}
      ) do
    self =
      self
      |> ensure_lap_exists(current_lap_number)
      |> ensure_lap_exists(timing_data.lap_number)
      |> maybe_fill_lap_time(current_lap_number, timing_data)
      |> maybe_fill_sector_times(current_lap_number, timing_data)

    self
  end

  def push_speed(
        self = %__MODULE__{},
        current_lap_number,
        speed
      ) do
    self =
      self
      |> ensure_lap_exists(current_lap_number)
      |> maybe_fill_top_speed(current_lap_number, speed)

    self
  end

  @doc """
  Determine outliers in the given laps based on lap time compared to
  all other laps that occurred around a similar time (+/- `@outlier_window_ms`).
  Lap is marked as an outlier if it's greater than `factor` * minimum lap time
  in the window.
  """
  def mark_outliers(laps = %__MODULE__{}, all_lap_times, around_ts \\ nil) do
    laps_to_check =
      laps.data
      |> Map.values()
      |> Stream.filter(fn lap ->
        cond do
          lap.timestamp == nil ->
            false

          around_ts == nil ->
            true

          abs(Timex.diff(around_ts, lap.timestamp, :millisecond)) < 2 * @outlier_window_ms ->
            true

          true ->
            false
        end
      end)
      |> sort_by(:number, :asc)

    laps_marked = do_mark_outliers(laps_to_check, all_lap_times, %{})
    laps_merged = Map.merge(laps.data, laps_marked)
    %{laps | data: laps_merged}
  end

  defp ensure_lap_exists(self, _current_lap_number = nil), do: self

  defp ensure_lap_exists(
         self = %__MODULE__{},
         lap_number
       ) do
    if self.data[lap_number] != nil do
      self
    else
      lap = %Lap{
        number: lap_number
      }

      data = Map.put(self.data, lap_number, lap)
      %{self | data: data}
    end
  end

  defp maybe_fill_lap_time(self, current_lap_number, timing_data)

  defp maybe_fill_lap_time(self, _current_lap_number, %TimingData{lap_time: nil}), do: self

  defp maybe_fill_lap_time(
         self = %__MODULE__{},
         current_lap_number,
         timing_data = %TimingData{}
       ) do
    lap_number = timing_data.lap_number || current_lap_number
    lap = self.data[lap_number]

    lap_ts_age_ms =
      if lap.timestamp != nil do
        DateTime.diff(timing_data.timestamp, lap.timestamp, :millisecond)
      else
        0
      end

    lap_num_diff = current_lap_number - lap_number

    cond do
      lap.time != nil ->
        Logger.warn(
          "Received lap time for lap #{lap_number} but it already has a time. Lap: #{inspect(lap)}, Data: #{inspect(timing_data)}"
        )

        self

      lap_ts_age_ms > @max_data_fill_delay_ms ->
        Logger.warn(
          "Received lap time for lap #{lap_number} but it is too old: #{lap_ts_age_ms}ms. Lap: #{inspect(lap)}, Data: #{inspect(timing_data)}"
        )

        self

      lap_num_diff > 1 ->
        Logger.warn(
          "Received lap time for lap #{lap_number} but it is too old: #{lap_num_diff} laps. Lap: #{inspect(lap)}, Data: #{inspect(timing_data)}"
        )

        self

      true ->
        ts = lap.timestamp || timing_data.timestamp
        lap = %{lap | time: timing_data.lap_time, timestamp: ts}
        data = Map.put(self.data, lap.number, lap)
        %{self | data: data}
    end
  end

  defp maybe_fill_sector_times(self, current_lap_number, timing_data)

  defp maybe_fill_sector_times(self, _current_lap_number, %TimingData{sector_times: nil}),
    do: self

  defp maybe_fill_sector_times(
         self = %__MODULE__{},
         current_lap_number,
         timing_data = %TimingData{}
       ) do
    self =
      timing_data.sector_times
      |> Enum.filter(fn {sector, sector_time} -> sector != nil and sector_time != nil end)
      |> Enum.reduce(self, fn {sector, _sector_time}, self ->
        self = maybe_fill_sector(self, current_lap_number, sector, timing_data)
        self
      end)

    self
  end

  defp maybe_fill_sector(
         self,
         current_lap_number,
         sector_num,
         timing_data = %TimingData{}
       ) do
    sector_time = timing_data.sector_times[sector_num]
    timestamp = timing_data.timestamp

    current_lap = self.data[current_lap_number]
    last_lap = self.data[current_lap_number - 1]

    last_lap_ts_age_ms =
      if last_lap != nil and last_lap.timestamp != nil do
        DateTime.diff(timestamp, last_lap.timestamp, :millisecond)
      else
        nil
      end

    curr_lap_has_sector = current_lap.sectors[sector_num] != nil

    last_lap_has_sector =
      if last_lap == nil do
        nil
      else
        last_lap.sectors[sector_num] != nil
      end

    can_fill_last_lap = last_lap_ts_age_ms != nil and last_lap_ts_age_ms < @max_data_fill_delay_ms

    lap_to_fill =
      cond do
        curr_lap_has_sector ->
          Logger.warn(
            "Received sector #{sector_num} time but current lap already has a time. Lap: #{inspect(current_lap)}, Data: #{inspect(timing_data)}"
          )

          nil

        last_lap == nil ->
          current_lap

        # Sector 3 time is sometimes received after the next lap has started
        sector_num == 3 and not last_lap_has_sector and can_fill_last_lap ->
          last_lap

        true ->
          current_lap
      end

    if lap_to_fill != nil do
      new_lap_ts =
        if sector_num == 3 do
          # Do not override existing (earlier) lap timestamp
          lap_to_fill.timestamp || timestamp
        else
          lap_to_fill.timestamp
        end

      sector = Sector.new(sector_time, timestamp)
      sectors = Map.put(lap_to_fill.sectors, sector_num, sector)

      lap = %{lap_to_fill | sectors: sectors, timestamp: new_lap_ts}
      data = Map.put(self.data, lap.number, lap)

      %{self | data: data}
    else
      self
    end
  end

  defp maybe_fill_top_speed(self, current_lap_number, speed) do
    lap = self.data[current_lap_number]

    if lap.top_speed < speed do
      lap = %{lap | top_speed: speed}
      data = Map.put(self.data, lap.number, lap)
      %{self | data: data}
    else
      self
    end
  end

  defp sort_by(laps, _field = :timestamp, direction) do
    Enum.sort_by(laps, fn l -> l.timestamp end, {direction, DateTime})
  end

  defp sort_by(laps, _field = :number, direction) do
    Enum.sort_by(laps, fn l -> l.number end, direction)
  end

  defp do_mark_outliers(_laps = [], _laps_window, acc), do: acc

  # all_lap_times_window needs to be sorted by timestamp
  defp do_mark_outliers([lap | rest_laps], all_lap_times_window, acc) do
    factor = 1.2

    with time when time != nil <- lap.time,
         time_ms = Timex.Duration.to_milliseconds(time),
         ts when ts != nil <- lap.timestamp do
      {window_time_ms, all_lap_times_window} =
        do_mark_outliers_find_window_time(all_lap_times_window, lap, @outlier_window_ms)

      lap =
        if window_time_ms != nil do
          is_outlier = time_ms > window_time_ms * factor
          %{lap | is_outlier: is_outlier}
        else
          lap
        end

      acc = Map.put(acc, lap.number, lap)
      do_mark_outliers(rest_laps, all_lap_times_window, acc)
    else
      nil ->
        acc = Map.put(acc, lap.number, lap)
        do_mark_outliers(rest_laps, all_lap_times_window, acc)
    end
  end

  defp do_mark_outliers_find_window_time(all_lap_times_window, lap, window_size_ms) do
    lap_ts_ms = DateTime.to_unix(lap.timestamp, :millisecond)
    discard_before_ms = lap_ts_ms - window_size_ms

    # Discard all laps older than the window to avoid walking through the whole list again
    {_discard, window_without_older_laps} =
      all_lap_times_window
      |> Enum.split_while(fn {ts_ms, _time_ms} ->
        ts_ms < discard_before_ms
      end)

    # Find all laps inside the window that we care about
    {relevant_laps, _rest} =
      window_without_older_laps
      |> Enum.split_while(fn {ts_ms, _time_ms} ->
        ts_ms < lap_ts_ms + window_size_ms
      end)

    window_time_ms =
      relevant_laps
      |> Stream.map(fn {_ts_ms, time_ms} -> time_ms end)
      |> Enum.min(fn -> nil end)

    {window_time_ms, window_without_older_laps}
  end

  defp min_time(a, b) when is_integer(a) and is_integer(b) do
    if a < b do
      a
    else
      b
    end
  end

  defp min_time(a = %Timex.Duration{}, b = %Timex.Duration{}) do
    min_time(
      Timex.Duration.to_milliseconds(a, truncate: true),
      Timex.Duration.to_milliseconds(b, truncate: true)
    )
  end

  defp min_time(a, b = %Timex.Duration{}) do
    min_time(a, Timex.Duration.to_milliseconds(b, truncate: true))
  end

  defp min_time(a = %Timex.Duration{}, b) do
    min_time(Timex.Duration.to_milliseconds(a, truncate: true), b)
  end

  defp min_time(_a = nil, b), do: b

  defp min_time(a, _b = nil), do: a

  defp max_val(_a = nil, b), do: b
  defp max_val(a, _b = nil), do: a

  defp max_val(a, b) when is_integer(a) and is_integer(b) do
    if a > b do
      a
    else
      b
    end
  end
end
