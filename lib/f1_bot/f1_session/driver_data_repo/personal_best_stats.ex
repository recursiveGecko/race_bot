defmodule F1Bot.F1Session.DriverDataRepo.PersonalBestStats do
  use TypedStruct

  typedstruct do
    field :driver_number, pos_integer()
    field :lap_time_ms, pos_integer() | nil
    field :sectors_ms, %{1 => pos_integer() | nil, 2 => pos_integer() | nil, 3 => pos_integer() | nil}
    field :top_speed, pos_integer() | nil
  end

  def new(driver_number), do: %__MODULE__{driver_number: driver_number}
end
