defmodule F1Bot.F1Session.DriverDataRepo.Stint do
  @moduledoc """
  Holds information about a single stint.
  """
  use TypedStruct

  typedstruct do
    @typedoc "Stint information"

    field(:number, pos_integer(), enforce: true)
    field(:compound, atom(), enforce: true)
    field(:age, non_neg_integer(), enforce: true)
    field(:tyres_changed, boolean(), enforce: true)
    field(:lap_number, non_neg_integer(), enforce: true)
  end

  def new(stint_data) do
    struct!(__MODULE__, stint_data)
  end

  def update(self = %__MODULE__{}, stint_data) do
    new_self = struct!(self, stint_data)
    has_changes = new_self != self
    {has_changes, new_self}
  end
end
