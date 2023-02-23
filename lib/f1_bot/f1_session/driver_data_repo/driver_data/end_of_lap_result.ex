defmodule F1Bot.F1Session.DriverDataRepo.DriverData.EndOfLapResult do
  @moduledoc """
  Result of pushing a lap time to DriverData repo, contains information
  about personal records, such as lap time and top speed deltas.
  """
  use TypedStruct

  typedstruct do
    field :driver_number, pos_integer(), enforce: true
    field :lap_time, Timex.Duration.t(), enforce: true
    field :is_fastest_lap, boolean(), enforce: true
    field :is_top_speed, boolean(), enforce: true
    field :lap_delta, Timex.Duration.t(), enforce: true
    field :speed_delta, integer(), enforce: true
    field :lap_top_speed, integer(), enforce: true
  end
end
