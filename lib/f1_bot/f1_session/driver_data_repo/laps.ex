defmodule F1Bot.F1Session.DriverDataRepo.Laps do
  @moduledoc """
  Stores all information about laps driven by a driver in the current session,
  e.g. lap number, lap time and timestamp.
  """
  use TypedStruct

  alias F1Bot.F1Session.DriverDataRepo.Lap

  @max_data_fill_delay_ms 15_000

  typedstruct do
    field(:data, [Lap.t()], default: [])
    field(:sectors, Lap.sector_map(), default: Lap.new_clean_sector_map())
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

  @doc """
  Starting with the last completed lap (by timestamp), finds the first lap that meets the following criteria:
  - lap was completed no more than `padding_ms` after the given timestamp
  - first lap completed before the given timestamp
  """
  def find_around_or_before(laps = %__MODULE__{}, timestamp = %DateTime{}, padding_ms) do
    search_ts_ms = DateTime.to_unix(timestamp, :millisecond) + padding_ms

    lap =
      laps.data
      |> sort_by_timestamp(:desc)
      |> Enum.find(fn l ->
        if l.timestamp != nil do
          ts_ms = DateTime.to_unix(l.timestamp, :millisecond)
          ts_ms <= search_ts_ms
        end
      end)

    case lap do
      nil -> {:error, :not_found}
      _ -> {:ok, lap}
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

  @spec fill_by_close_timestamp(t(), keyword(), DateTime.t(), [{pos_integer(), pos_integer()}]) ::
          {:ok, t()} | {:error, atom()}
  def fill_by_close_timestamp(
        self = %__MODULE__{},
        args,
        timestamp,
        all_lap_times \\ []
      ) do
    if accept_lap_information?(self, args, timestamp) do
      self =
        do_fill_by_close_timestamp(self, args, timestamp)
        |> mark_outliers(all_lap_times)
        |> fix_laps_data()

      self =
        if args[:time] do
          mark_outliers(self, all_lap_times)
        else
          self
        end

      {:ok, self}
    else
      {:error, :missing_prerequisites}
    end
  end

  @spec fill_sector_times(t(), pos_integer(), Timex.Duration.t(), DateTime.t()) ::
          t()
  def fill_sector_times(
        self = %__MODULE__{sectors: sectors},
        sector,
        sector_time,
        timestamp
      )
      when sector in [1, 2, 3] do
    sectors =
      sectors
      |> put_in([sector, :time], sector_time)
      |> put_in([sector, :timestamp], timestamp)

    if sector == 3 do
      {:ok, laps} = fill_by_close_timestamp(self, [sectors: sectors], timestamp)
      laps = clear_sector_data(laps)

      laps
    else
      %{self | sectors: sectors}
    end
  end

  def fix_laps_data(self = %__MODULE__{data: laps}) do
    new_laps =
      laps
      |> sort_by_timestamp(:asc)
      |> do_fix_laps_data([])
      |> sort_by_timestamp(:desc)

    %{self | data: new_laps}
  end

  defp sort_by_timestamp(laps, direction) do
    Enum.sort_by(laps, fn l -> l.timestamp end, {direction, DateTime})
  end

  defp do_fill_by_close_timestamp(
         self = %__MODULE__{data: data},
         args,
         timestamp
       ) do
    {found, data_reversed} =
      Enum.reduce(data, {_skip = false, _new_data = []}, fn lap, {skip, data} ->
        cond do
          skip == true ->
            data = [lap | data]
            {skip, data}

          should_fill_lap?(lap, timestamp) ->
            lap = Lap.merge_with_args(lap, args)
            data = [lap | data]
            {true, data}

          true ->
            data = [lap | data]
            {false, data}
        end
      end)

    if found do
      %{self | data: Enum.reverse(data_reversed)}
    else
      args = Keyword.put_new(args, :timestamp, timestamp)
      lap = Lap.new(args)

      %{self | data: [lap | data]}
    end
  end

  defp accept_lap_information?(%__MODULE__{sectors: sectors}, args, _timestamp) do
    cond do
      # Ignore received lap time if we hadn't received any sector times prior to this
      # See Canada 2022 quali integration test
      Keyword.has_key?(args, :time) ->
        Lap.has_any_sector_time?(sectors)

      true ->
        true
    end
  end

  defp do_fix_laps_data(_laps = [first, second | rest], acc) do
    first_is_candidate = first.number == nil

    second_is_candidate = second.number != nil and second.time == nil and second.sectors == nil

    if first_is_candidate and second_is_candidate do
      first = %{first | number: second.number}
      do_fix_laps_data(rest, [first | acc])
    else
      do_fix_laps_data([second | rest], [first | acc])
    end
  end

  defp do_fix_laps_data(laps, acc) do
    acc ++ laps
  end

  defp clear_sector_data(self = %__MODULE__{}) do
    %{self | sectors: Lap.new_clean_sector_map()}
  end

  defp should_fill_lap?(lap, ts) do
    delta_ms = Timex.diff(lap.timestamp, ts, :milliseconds) |> abs()
    delta_ms < @max_data_fill_delay_ms
  end

  @doc """
  Determine outliers in the given laps based on lap time compared to
  all other laps that occurred around a similar time (+/- `outlier_window_ms`).
  Lap is marked as an outlier if it's greater than `factor` * minimum lap time
  in the window.
  """
  def mark_outliers(laps = %__MODULE__{}, all_lap_times) do
    laps_sorted = sort_by_timestamp(laps.data, :asc)
    laps_marked = do_mark_outliers(laps_sorted, all_lap_times, [])

    %{laps | data: laps_marked}
  end

  defp do_mark_outliers(_laps = [], _laps_window, acc), do: Enum.reverse(acc)

  defp do_mark_outliers([lap | rest_laps], all_lap_times_window, acc) do
    factor = 100.2
    outlier_window_ms = 60_000 * 2

    with time when time != nil <- lap.time,
         time_ms = Timex.Duration.to_milliseconds(time),
         ts when ts != nil <- lap.timestamp do
      {window_time_ms, all_lap_times_window} =
        do_mark_outliers_find_window_time(all_lap_times_window, lap, outlier_window_ms)

      lap =
        if window_time_ms != nil do
          is_outlier = time_ms > window_time_ms * factor
          %{lap | is_outlier: is_outlier}
        else
          lap
        end

      do_mark_outliers(rest_laps, all_lap_times_window, [lap | acc])
    else
      nil ->
        do_mark_outliers(rest_laps, all_lap_times_window, [lap | acc])
    end
  end

  defp do_mark_outliers_find_window_time(all_lap_times_window, lap, window_size_ms) do
    lap_ts_ms = DateTime.to_unix(lap.timestamp, :millisecond)
    discard_before_ms = lap_ts_ms - window_size_ms

    {_discard, window_without_older_laps} =
      all_lap_times_window
      |> Enum.split_while(fn {ts_ms, _time_ms} ->
        ts_ms < discard_before_ms
      end)

    {relevant_laps, _rest} =
      window_without_older_laps
      |> Enum.split_while(fn {ts_ms, _time_ms} ->
        ts_ms < lap_ts_ms + window_size_ms
      end)

    window_time_ms =
      relevant_laps
      |> Enum.map(fn {_ts_ms, time_ms} -> time_ms end)
      |> Enum.min(fn -> nil end)

    {window_time_ms, window_without_older_laps}
  end
end
