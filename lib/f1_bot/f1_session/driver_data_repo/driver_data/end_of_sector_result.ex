defmodule F1Bot.F1Session.DriverDataRepo.DriverData.EndOfSectorResult do
  @moduledoc """
  Result of pushing a sector time to DriverData repo, contains information
  about personal best sector times
  """
  use TypedStruct

  typedstruct do
    field :driver_number, pos_integer(), enforce: true
    field :sector, pos_integer(), enforce: true
    field :sector_time, Timex.Duration.t(), enforce: true
  end
end
