defmodule F1Bot.F1Session.DriverDataRepo.BestStats do
  @moduledoc """
  Processes and holds best-of session statistics, such as the overall fastest lap and top speed.
  """
  use TypedStruct

  @type fastest_sectors :: %{
          1 => Timex.Duration.t() | nil,
          2 => Timex.Duration.t() | nil,
          3 => Timex.Duration.t() | nil
        }

  typedstruct do
    @typedoc "Session-wide stats for fastest laps, top speed across all drivers"

    field(:fastest_lap, Timex.Duration.t(), default: nil)
    field(:top_speed, non_neg_integer(), default: nil)
    field(:fastest_sectors, fastest_sectors(), default: %{1 => nil, 2 => nil, 3 => nil})
  end

  def new() do
    %__MODULE__{}
  end

  def push_lap_time(
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

  def push_top_speed(
        self = %__MODULE__{top_speed: top_speed},
        speed
      ) do
    if top_speed == nil do
      self = %{self | top_speed: speed}
      {self, false, nil}
    else
      delta = speed - top_speed

      if delta > 0 do
        self = %{self | top_speed: speed}
        {self, true, delta}
      else
        {self, false, nil}
      end
    end
  end

  def push_sector_time(
        self = %__MODULE__{fastest_sectors: fastest_sectors},
        sector,
        sector_time = %Timex.Duration{}
      )
      when sector in [1, 2, 3] do
    curr_fastest_time = fastest_sectors[sector]

    if curr_fastest_time == nil do
      fastest_sectors = Map.put(fastest_sectors, sector, sector_time)
      self = %{self | fastest_sectors: fastest_sectors}
      {self, true, nil}
    else
      delta = Timex.Duration.diff(sector_time, curr_fastest_time)
      delta_ms = Timex.Duration.to_milliseconds(delta)

      if delta_ms < 0 do
        fastest_sectors = Map.put(fastest_sectors, sector, sector_time)

        self = %{self | fastest_sectors: fastest_sectors}
        {self, true, delta}
      else
        {self, false, nil}
      end
    end
  end
end
