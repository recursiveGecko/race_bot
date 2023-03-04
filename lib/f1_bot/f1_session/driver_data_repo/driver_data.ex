defmodule F1Bot.F1Session.DriverDataRepo.DriverData do
  @moduledoc """
  Coordinates processing and stores data for a driver, e.g. laps, fastest lap,
  car telemetry, stint data and more.
  """
  use TypedStruct

  alias F1Bot.LightCopy
  alias F1Bot.F1Session.DriverDataRepo.{Laps, Stints}

  alias F1Bot.F1Session.LiveTimingHandlers.TimingData
  alias F1Bot.F1Session.Common.TimeSeriesStore

  typedstruct do
    @typedoc "Driver session data"

    field(:number, pos_integer(), enforce: true)
    field(:current_lap_number, non_neg_integer(), default: 1)
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

  def push_timing_data(
        self = %__MODULE__{},
        timing_data = %TimingData{},
        all_lap_times
      ) do
    is_end_of_lap = timing_data.lap_time != nil or timing_data.sector_times[3] != nil

    laps = Laps.push_timing_data(self.laps, self.current_lap_number, timing_data)

    laps =
      if is_end_of_lap do
        Laps.mark_outliers(laps, all_lap_times, timing_data.timestamp)
      else
        laps
      end

    # Maybe update current lap number
    lap_num = timing_data.lap_number

    new_current_lap_num =
      if lap_num != nil and lap_num + 1 > self.current_lap_number do
        lap_num + 1
      else
        self.current_lap_number
      end

    self = %{self | laps: laps, current_lap_number: new_current_lap_num}

    self
  end

  def personal_best_stats(self = %__MODULE__{}) do
    min_time_stats = Laps.personal_best_stats(self.laps)
    %{min_time_stats | driver_number: self.number}
  end

  def push_telemetry(
        self = %__MODULE__{telemetry_hist: telemetry_hist},
        telemetry
      ) do
    telemetry_hist = TimeSeriesStore.push_data(telemetry_hist, telemetry)

    self
    |> Map.put(:telemetry_hist, telemetry_hist)
    |> push_speed_to_lap(telemetry)
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

  defp push_speed_to_lap(self = %__MODULE__{}, _telemetry = %{speed: speed}) when is_integer(speed) do
    laps = Laps.push_speed(self.laps, self.current_lap_number, speed)
    %{self | laps: laps}
  end

  defp push_speed_to_lap(self = %__MODULE__{}, _telemetry), do: self

  defimpl LightCopy do
    def light_copy(self) do
      empty_hist = TimeSeriesStore.new()
      %{self | telemetry_hist: empty_hist, position_hist: empty_hist}
    end
  end
end
