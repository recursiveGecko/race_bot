defmodule F1Bot.F1Session.DriverDataRepo.DriverData do
  @moduledoc """
  Coordinates processing and stores data for a driver, e.g. laps, fastest lap,
  car telemetry, stint data and more.
  """
  use TypedStruct

  alias F1Bot.LightCopy
  alias F1Bot.F1Session.DriverDataRepo.{Laps, Stints}

  alias F1Bot.F1Session.DriverDataRepo.DriverData.{
    EndOfLapResult,
    EndOfSectorResult
  }

  alias F1Bot.F1Session.Common.TimeSeriesStore

  typedstruct do
    @typedoc "Driver session data"

    field(:number, pos_integer(), enforce: true)
    field(:current_lap_number, non_neg_integer(), default: 1)
    field(:fastest_lap, Timex.Duration.t(), default: nil)
    field(:top_speed, non_neg_integer(), default: nil)
    field(:top_speed_curr_lap, non_neg_integer(), default: nil)
    field(:laps, Laps.t(), default: Laps.new())
    field(:stints, Stints.t(), default: Stints.new())
    field(:telemetry_hist, TimeSeriesStore.t(), default: TimeSeriesStore.new())
    field(:position_hist, TimeSeriesStore.t(), default: TimeSeriesStore.new())
  end

  def new(number) when is_integer(number) do
    %__MODULE__{
      number: number
    }
  end

  def push_lap_time(
        self = %__MODULE__{},
        lap_time = %Timex.Duration{},
        timestamp
      ) do
    fill_result =
      self.laps
      |> Laps.fill_by_close_timestamp([time: lap_time], timestamp)

    case fill_result do
      {:ok, laps} ->
        {self, is_fastest_lap, lap_delta} = maybe_replace_fastest_lap(self, lap_time)
        {self, is_top_speed, speed_delta} = maybe_replace_top_speed_after_lap(self)

        result = %EndOfLapResult{
          driver_number: self.number,
          lap_time: lap_time,
          is_fastest_lap: is_fastest_lap,
          is_top_speed: is_top_speed,
          lap_delta: lap_delta,
          speed_delta: speed_delta,
          lap_top_speed: self.top_speed_curr_lap
        }

        self = reset_current_lap_stats(self)

        self = %{self | laps: laps}
        {:ok, {self, result}}

      {:error, error} ->
        {:error, error}
    end
  end

  def push_sector_time(
        self = %__MODULE__{},
        sector,
        sector_time = %Timex.Duration{},
        timestamp
      ) do
    laps =
      self.laps
      |> Laps.fill_sector_times(sector, sector_time, timestamp)

    self = %{self | laps: laps}

    result = %EndOfSectorResult{
      driver_number: self.number,
      sector: sector,
      sector_time: sector_time
    }

    {self, result}
  end

  @spec push_lap_number(t(), pos_integer() | nil, DateTime.t()) :: t()
  def push_lap_number(
        self = %__MODULE__{},
        lap_number,
        timestamp
      )
      when is_integer(lap_number) do
    {:ok, laps} =
      self.laps
      |> Laps.fill_by_close_timestamp([number: lap_number], timestamp)

    new_lap_number =
      if lap_number >= self.current_lap_number do
        lap_number + 1
      else
        self.current_lap_number
      end

    %{self | laps: laps, current_lap_number: new_lap_number}
  end

  def push_telemetry(
        self = %__MODULE__{telemetry_hist: telemetry_hist},
        telemetry
      ) do
    telemetry_hist = TimeSeriesStore.push_data(telemetry_hist, telemetry)

    self
    |> maybe_replace_top_speed_curr_lap(telemetry)
    |> Map.put(:telemetry_hist, telemetry_hist)
  end

  def push_position(
        self = %__MODULE__{position_hist: position_hist},
        position
      ) do
    position_hist = TimeSeriesStore.push_data(position_hist, position)

    %{self | position_hist: position_hist}
  end

  def push_stint_data(
        self = %__MODULE__{stints: stints},
        stint_data
      ) do
    {change_type, new_stints} =
      stints
      |> Stints.push_stint_data(stint_data, self.current_lap_number)

    # Update: This has now been disabled as it was causing more issues than it was solving
    # new_stints = Stints.fix_stint_data(new_stints, self.laps)
    new_stints = Stints.normalize(new_stints)

    self = %{self | stints: new_stints}

    if change_type in [:new_with_compound, :late_set_current_compound, :updated_current_compound] do
      {:ok, stint} = Stints.find_stint(new_stints, stint_data.number)

      result = %{
        is_correction: change_type == :updated_current_compound,
        stint: stint
      }

      {self, result}
    else
      {self, nil}
    end
  end

  @spec outlap_lap_numbers(t()) :: [pos_integer()]
  def outlap_lap_numbers(self = %__MODULE__{}) do
    self.stints.data
    |> Enum.map(fn s -> s.lap_number end)
    |> Enum.reject(&(&1 == nil))
  end

  # Returns {self, is_fastest_lap, lap_delta}
  defp maybe_replace_fastest_lap(
         self = %__MODULE__{fastest_lap: fastest_lap},
         lap_time = %Timex.Duration{}
       ) do
    if fastest_lap == nil do
      self = %{self | fastest_lap: lap_time}
      {self, true, nil}
    else
      delta = Timex.Duration.diff(lap_time, fastest_lap)
      delta_ms = Timex.Duration.to_milliseconds(delta)

      if delta_ms < 0 do
        self = %{self | fastest_lap: lap_time}
        {self, true, delta}
      else
        {self, false, nil}
      end
    end
  end

  defp maybe_replace_top_speed_curr_lap(
         self = %__MODULE__{top_speed_curr_lap: top_speed_curr_lap},
         _telemetry = %{speed: speed}
       ) do
    if top_speed_curr_lap == nil do
      %{self | top_speed_curr_lap: speed}
    else
      if speed > top_speed_curr_lap do
        %{self | top_speed_curr_lap: speed}
      else
        self
      end
    end
  end

  defp maybe_replace_top_speed_after_lap(
         self = %__MODULE__{
           top_speed: top_speed,
           top_speed_curr_lap: top_speed_curr_lap
         }
       ) do
    {self, is_top_speed, speed_delta} =
      if top_speed_curr_lap != nil and (top_speed == nil or top_speed_curr_lap > top_speed) do
        speed_delta =
          if top_speed == nil do
            nil
          else
            top_speed_curr_lap - top_speed
          end

        self = %{self | top_speed: top_speed_curr_lap}
        {self, true, speed_delta}
      else
        {self, false, nil}
      end

    {self, is_top_speed, speed_delta}
  end

  defp reset_current_lap_stats(self) do
    %{self | top_speed_curr_lap: nil}
  end

  defimpl LightCopy do
    def light_copy(self) do
      empty_hist = TimeSeriesStore.new()
      %{self | telemetry_hist: empty_hist, position_hist: empty_hist}
    end
  end
end
