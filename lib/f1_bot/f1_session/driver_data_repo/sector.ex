defmodule F1Bot.F1Session.DriverDataRepo.Sector do
  @moduledoc """
  Holds information about a single sector.
  """
  use TypedStruct

  typedstruct do
    field(:time, Timex.Duration.t())
    field(:timestamp, DateTime.t())
  end

  def new(time = %Timex.Duration{}, timestamp = %DateTime{}),
    do: %__MODULE__{
      time: time,
      timestamp: timestamp
    }
end
