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
    field(:total_laps, non_neg_integer(), enforce: true)
    field(:tyres_changed, boolean(), enforce: true)
    field(:lap_number, non_neg_integer(), enforce: true)
    field(:timestamp, DateTime, enforce: true)
  end

  def new(stint_data) do
    struct!(__MODULE__, stint_data)
  end

  def update(self = %__MODULE__{}, stint_data) do
    old = Map.from_struct(self)

    data =
      Map.merge(
        old,
        stint_data,
        fn k, v1, v2 -> merge_fn(old, stint_data, k, v1, v2) end
      )

    new_self = struct!(__MODULE__, data)

    update_type =
      cond do
        self.compound == nil and new_self.compound != nil ->
          :changed_compound_from_nil

        self.compound != new_self.compound ->
          :changed_compound

        new_self == self ->
          :no_changes

        true ->
          :other_fields
      end

    {update_type, new_self}
  end

  def count_laps(self = %__MODULE__{}) do
    cond do
      self.total_laps == nil -> nil
      self.age == nil -> self.total_laps
      true -> self.total_laps - self.age
    end
  end

  defp merge_fn(_self_map, _stint_data, _key = :timestamp, v1, v2) do
    # TODO: Timestamp should be set only once when the stint starts except when the stint
    # has been erroneously started earlier in the session (occasional SignalR API bug)
    cond do
      v2 == nil -> v1
      v1 == nil -> v2
      true -> v1
    end
  end

  defp merge_fn(_self_map, _stint_data, _key, v1, v2) do
    if v2 == nil do
      v1
    else
      v2
    end
  end
end
