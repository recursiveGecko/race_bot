defmodule F1Bot.F1Session.DriverDataRepo.BestStats do
  @moduledoc """
  Processes and holds personal best and session-best statistics,
  such as fastest lap times, sector times, and top speed.
  """
  use TypedStruct

  alias F1Bot.F1Session.DriverDataRepo.{Events, PersonalBestStats}

  @type fastest_sectors :: %{
          1 => pos_integer() | nil,
          2 => pos_integer() | nil,
          3 => pos_integer() | nil
        }

  typedstruct do
    @typedoc "Session-wide stats for fastest laps, top speed across all drivers"

    field(:fastest_lap_ms, pos_integer() | nil, default: nil)
    field(:fastest_sectors, fastest_sectors(), default: %{1 => nil, 2 => nil, 3 => nil})
    field(:top_speed, non_neg_integer() | nil, default: nil)
    field(:personal_best, %{pos_integer() => PersonalBestStats.t()}, default: %{})
  end

  def new() do
    %__MODULE__{}
  end

  def push_personal_best_stats(
        self = %__MODULE__{},
        pb_stats = %PersonalBestStats{}
      ) do
    prev_pb_stats =
      self.personal_best[pb_stats.driver_number] ||
        PersonalBestStats.new(pb_stats.driver_number)

    {self, events} =
      {self, []}
      |> evaluate_lap_time(pb_stats, prev_pb_stats)
      |> evaluate_top_speed(pb_stats, prev_pb_stats)
      |> evaluate_sector_times(pb_stats, prev_pb_stats)

    new_pb_map = Map.put(self.personal_best, pb_stats.driver_number, pb_stats)
    self = %{self | personal_best: new_pb_map}

    {self, events}
  end

  defp evaluate_sector_times({self, events}, pb_stats, prev_pb_stats) do
    [1, 2, 3]
    |> Enum.reduce({self, events}, fn sector, {self, events} ->
      evaluate_sector({self, events}, pb_stats, prev_pb_stats, sector)
    end)
  end

  defp evaluate_sector(
         {
           self = %__MODULE__{fastest_sectors: fastest_sectors},
           events
         },
         pb_stats = %PersonalBestStats{sectors_ms: new_sectors_ms},
         _prev_pb_stats = %PersonalBestStats{sectors_ms: prev_sectors_ms},
         sector
       ) do
    session_sector_ms = fastest_sectors[sector]
    new_sector_ms = new_sectors_ms[sector]
    prev_sector_ms = prev_sectors_ms[sector]

    {best_type, best_delta_ms} =
      cond do
        new_sector_ms == nil ->
          {:none, nil}

        session_sector_ms == nil ->
          {:overall, nil}

        new_sector_ms < session_sector_ms ->
          {:overall, new_sector_ms - session_sector_ms}

        prev_sector_ms == nil ->
          {:personal, nil}

        new_sector_ms < prev_sector_ms ->
          {:personal, new_sector_ms - prev_sector_ms}

        true ->
          {:none, nil}
      end

    best_delta = ms_to_duration(best_delta_ms)

    event =
      case best_type do
        :none ->
          nil

        type ->
          Events.make_agg_fastest_sector_event(
            pb_stats.driver_number,
            type,
            sector,
            ms_to_duration(new_sector_ms),
            best_delta
          )
      end

    self =
      if best_type == :overall do
        fastest_sectors = Map.put(fastest_sectors, sector, new_sector_ms)
        %{self | fastest_sectors: fastest_sectors}
      else
        self
      end

    events = List.wrap(event) ++ events
    {self, events}
  end

  defp evaluate_lap_time(
         {
           self = %__MODULE__{fastest_lap_ms: session_lap_time_ms},
           events
         },
         pb_stats = %PersonalBestStats{lap_time_ms: new_lap_time_ms},
         _prev_pb_stats = %PersonalBestStats{lap_time_ms: prev_lap_time_ms}
       ) do
    {best_type, best_delta_ms} =
      cond do
        new_lap_time_ms == nil ->
          {:none, nil}

        session_lap_time_ms == nil ->
          {:overall, nil}

        new_lap_time_ms < session_lap_time_ms ->
          {:overall, new_lap_time_ms - session_lap_time_ms}

        prev_lap_time_ms == nil ->
          {:personal, nil}

        new_lap_time_ms < prev_lap_time_ms ->
          {:personal, new_lap_time_ms - prev_lap_time_ms}

        true ->
          {:none, nil}
      end

    best_delta = ms_to_duration(best_delta_ms)

    event =
      case best_type do
        :none ->
          nil

        type ->
          Events.make_agg_fastest_lap_event(
            pb_stats.driver_number,
            type,
            ms_to_duration(new_lap_time_ms),
            best_delta
          )
      end

    self =
      if best_type == :overall do
        %{self | fastest_lap_ms: new_lap_time_ms}
      else
        self
      end

    events = List.wrap(event) ++ events
    {self, events}
  end

  defp evaluate_top_speed(
         {
           self = %__MODULE__{top_speed: session_top_speed},
           events
         },
         pb_stats = %PersonalBestStats{top_speed: new_top_speed},
         _prev_pb_stats = %PersonalBestStats{top_speed: prev_top_speed}
       ) do
    {best_type, best_delta} =
      cond do
        new_top_speed == nil ->
          {:none, nil}

        session_top_speed == nil ->
          {:overall, nil}

        new_top_speed > session_top_speed ->
          {:overall, new_top_speed - session_top_speed}

        prev_top_speed == nil ->
          {:personal, nil}

        new_top_speed > prev_top_speed ->
          {:personal, new_top_speed - prev_top_speed}

        true ->
          {:none, nil}
      end

    event =
      case best_type do
        :none ->
          nil

        type ->
          Events.make_agg_top_speed_event(
            pb_stats.driver_number,
            type,
            new_top_speed,
            best_delta
          )
      end

    self =
      if best_type == :overall do
        %{self | top_speed: new_top_speed}
      else
        self
      end

    events = List.wrap(event) ++ events
    {self, events}
  end

  defp ms_to_duration(_ms = nil), do: nil
  defp ms_to_duration(ms), do: Timex.Duration.from_milliseconds(ms)
end
