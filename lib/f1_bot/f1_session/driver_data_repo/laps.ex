defmodule F1Bot.F1Session.DriverDataRepo.Laps do
  @moduledoc """
  Stores all information about laps driven by a driver in the current session,
  e.g. lap number, lap time and timestamp.
  """
  use TypedStruct

  alias F1Bot.F1Session.DriverDataRepo.Lap

  typedstruct do
    field(:data, [Lap.t()], default: [])
    field(:sectors, Lap.sector_map(), default: Lap.new_clean_sector_map())
  end

  def new() do
    %__MODULE__{}
  end

  def sort_by_number(laps, direction \\ :asc) do
    Enum.sort_by(laps, fn l -> l.number end, direction)
  end

  def sort_by_timestamp(laps, direction \\ :asc) do
    Enum.sort_by(laps, fn l -> l.timestamp end, {direction, DateTime})
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

  @spec fill_by_close_timestamp(t(), keyword(), DateTime.t(), pos_integer()) ::
          {:ok, t()} | {:error, atom()}
  def fill_by_close_timestamp(
        self = %__MODULE__{},
        args,
        timestamp,
        max_deviation_ms
      ) do
    if accept_lap_information?(self, args, timestamp) do
      self = do_fill_by_close_timestamp(self, args, timestamp, max_deviation_ms)
      {:ok, self}
    else
      {:error, :missing_prerequisites}
    end
  end

  @spec fill_sector_times(t(), pos_integer(), Timex.Duration.t(), DateTime.t(), pos_integer) ::
          t()
  def fill_sector_times(
        self = %__MODULE__{sectors: sectors},
        sector,
        sector_time,
        timestamp,
        max_deviation_ms
      )
      when sector in [1, 2, 3] do
    sectors =
      sectors
      |> put_in([sector, :time], sector_time)
      |> put_in([sector, :timestamp], timestamp)

    if sector == 3 do
      {:ok, laps} = fill_by_close_timestamp(self, [sectors: sectors], timestamp, max_deviation_ms)
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

  defp do_fill_by_close_timestamp(
         self = %__MODULE__{data: data},
         args,
         timestamp,
         max_deviation_ms
       ) do
    {found, data_reversed} =
      Enum.reduce(data, {_skip = false, _new_data = []}, fn lap, {skip, data} ->
        cond do
          skip == true ->
            data = [lap | data]
            {skip, data}

          should_fill_lap?(lap, timestamp, max_deviation_ms) ->
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
      |> fix_laps_data()
    else
      args = Keyword.put_new(args, :timestamp, timestamp)
      lap = Lap.new(args)

      %{self | data: [lap | data]}
      |> fix_laps_data()
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

  defp should_fill_lap?(lap, ts, max_ms) do
    delta_ms = Timex.diff(lap.timestamp, ts, :milliseconds) |> abs()

    delta_ms < max_ms
  end
end
