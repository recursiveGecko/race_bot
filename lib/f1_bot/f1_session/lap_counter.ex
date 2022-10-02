defmodule F1Bot.F1Session.LapCounter do
  @moduledoc """
  Stores current and maximum lap number for the session
  """
  use TypedStruct

  alias F1Bot.F1Session.Common.Event

  typedstruct do
    field(:current, integer() | nil)
    field(:total, integer() | nil)
  end

  def new() do
    %__MODULE__{
      current: nil,
      total: nil
    }
  end

  def new(current, total) do
    %__MODULE__{
      current: current,
      total: total
    }
  end

  def update(old, new) do
    old = Map.from_struct(old)
    new = Map.from_struct(new)

    merged =
      Map.merge(old, new, fn _k, old_v, new_v ->
        if new_v == nil do
          old_v
        else
          new_v
        end
      end)

    struct!(__MODULE__, merged)
  end

  def to_event(lap_counter = %__MODULE__{}) do
    Event.new(:lap_counter, :changed, lap_counter)
  end
end
