defmodule F1Bot.F1Session.TrackStatusHistory do
  @moduledoc """
  Stores intervals when the race is neutralized (VSC, SC, red flag)
  """
  use TypedStruct

  @type status :: :all_clear | :yellow_flag | :safety_car | :red_flag | :virtual_safety_car

  @type interval :: %{
          starts_at: DateTime.t(),
          ends_at: DateTime.t() | nil,
          status: status()
        }

  typedstruct do
    field(:intervals, [interval()], default: [])
  end

  @spec new() :: t()
  def new(), do: %__MODULE__{}

  @spec new_interval(status(), DateTime.t(), DateTime.t() | nil) :: interval()
  def new_interval(track_status, starts_at, ends_at \\ nil) do
    %{
      starts_at: starts_at,
      ends_at: ends_at,
      status: track_status
    }
  end

  @spec push_track_status(t(), status(), DateTime.t()) :: t()
  def push_track_status(self = %__MODULE__{intervals: intervals}, track_status, timestamp) do
    intervals = maybe_end_previous_interval(intervals, timestamp)

    intervals =
      if track_status == :all_clear do
        intervals
      else
        i = new_interval(track_status, timestamp)
        [i | intervals]
      end

    %{self | intervals: intervals}
  end

  @spec find_intervals_with_status(t(), [status()]) :: [interval()]
  def find_intervals_with_status(_self = %__MODULE__{intervals: intervals}, statuses) do
    Enum.filter(intervals, fn i -> i.status in statuses end)
  end

  defp maybe_end_previous_interval([last | rest], timestamp) do
    last =
      if last.ends_at == nil do
        %{last | ends_at: timestamp}
      else
        last
      end

    [last | rest]
  end

  defp maybe_end_previous_interval(rest, _timestamp) do
    rest
  end
end
