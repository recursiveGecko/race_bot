defmodule F1Bot.F1Session.DriverDataRepo.Lap do
  @moduledoc """
  Holds information about a single lap.
  """
  use TypedStruct

  @type sector_data :: %{
          time: Timex.Duration.t() | nil,
          timestamp: DateTime.t() | nil
        }

  @type sector_map :: %{
          1 => sector_data(),
          2 => sector_data(),
          3 => sector_data()
        }

  typedstruct do
    @typedoc "Lap information"

    field(:number, pos_integer())
    field(:time, Timex.Duration.t())
    field(:timestamp, DateTime, enforce: true)
    field(:sectors, sector_map())
  end

  @spec new_clean_sector_map() :: sector_map()
  def new_clean_sector_map,
    do: %{
      1 => %{time: nil, timestamp: nil},
      2 => %{time: nil, timestamp: nil},
      3 => %{time: nil, timestamp: nil}
    }
end
