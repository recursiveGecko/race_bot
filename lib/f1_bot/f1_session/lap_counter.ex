defmodule F1Bot.F1Session.LapCounter do
  @moduledoc """
  Stores current and maximum lap number for the session
  """
  use TypedStruct

  alias F1Bot.F1Session.Common.Event

  typedstruct do
    field(:current, integer() | nil)
    field(:total, integer() | nil)
    field(:lap_timestamps, map(), default: %{})
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

  def update(lap_counter, current_lap, total_laps, timestamp) do
    lap_counter = update_timestamps(lap_counter, current_lap, timestamp)

    new_current_lap = current_lap || lap_counter.current
    new_total_laps = total_laps || lap_counter.total

    %{lap_counter | current: new_current_lap, total: new_total_laps}
  end

  def timestamp_to_lap_number(lap_counter, timestamp) do
    lap_counter.lap_timestamps
    |> Enum.sort_by(fn {lap, _timestamps} -> lap end, :asc)
    |> Enum.find_value(fn {lap, lap_ts} ->
      if F1Bot.Time.between?(timestamp, lap_ts.start, lap_ts.end) do
        lap
      else
        nil
      end
    end)
    |> case do
      nil -> {:error, :not_found}
      lap -> {:ok, lap}
    end
  end

  def to_event(lap_counter = %__MODULE__{}) do
    Event.new(:lap_counter, :changed, lap_counter)
  end

  defp update_timestamps(lap_counter, _current_lap = nil, _timestamp), do: lap_counter

  defp update_timestamps(lap_counter, current_lap, timestamp) when is_integer(current_lap) do
    lap_timestamps =
      lap_counter.lap_timestamps
      |> Map.update(
        current_lap,
        %{start: timestamp, end: nil},
        &MapUtils.patch_missing(&1, %{start: timestamp})
      )

    lap_counter = %{lap_counter | lap_timestamps: lap_timestamps}

    lap_counter
    |> maybe_update_prev_lap_timestamp(current_lap, timestamp)
  end

  defp maybe_update_prev_lap_timestamp(lap_counter, current_lap, timestamp) do
    if current_lap > 1 do
      prev_lap = current_lap - 1

      lap_timestamps =
        lap_counter.lap_timestamps
        |> Map.update(
          prev_lap,
          %{start: nil, end: timestamp},
          &MapUtils.patch_missing(&1, %{end: timestamp})
        )

      %{lap_counter | lap_timestamps: lap_timestamps}
    else
      lap_counter
    end
  end
end
