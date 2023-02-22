defmodule F1Bot.F1Session.TrackStatusHistory do
  @moduledoc """
  Stores intervals when the race is neutralized (VSC, SC, red flag)
  """
  use TypedStruct

  alias F1Bot.F1Session.Common.Event

  @type status :: :all_clear | :yellow_flag | :safety_car | :red_flag | :virtual_safety_car

  @type interval :: %{
          starts_at: DateTime.t(),
          ends_at: DateTime.t() | nil,
          start_lap: pos_integer(),
          end_lap: pos_integer() | nil,
          status: status()
        }

  typedstruct do
    field(:intervals, [interval()], default: [])
  end

  @spec new() :: t()
  def new(), do: %__MODULE__{}

  @spec new_interval(
          status(),
          DateTime.t(),
          DateTime.t() | nil,
          pos_integer() | nil,
          pos_integer() | nil
        ) :: interval()
  def new_interval(track_status, starts_at, ends_at \\ nil, start_lap \\ nil, end_lap \\ nil) do
    %{
      starts_at: starts_at,
      ends_at: ends_at,
      start_lap: start_lap,
      end_lap: end_lap,
      status: track_status
    }
  end

  @spec push_track_status(t(), status(), pos_integer(), DateTime.t()) :: {t(), [Event.t()]}
  def push_track_status(
        self = %__MODULE__{intervals: intervals},
        track_status,
        lap_number,
        timestamp
      ) do
    intervals = maybe_end_previous_interval(intervals, lap_number, timestamp)

    intervals =
      if track_status == :all_clear do
        intervals
      else
        i = new_interval(track_status, timestamp, nil, lap_number, nil)
        [i | intervals]
      end

    self = %{self | intervals: intervals}
    events = to_chart_events(self)
    {self, events}
  end

  @spec find_intervals_with_status(t(), [status()]) :: [interval()]
  def find_intervals_with_status(_self = %__MODULE__{intervals: intervals}, statuses) do
    Enum.filter(intervals, fn i -> i.status in statuses end)
  end

  @spec to_chart_events(t()) :: [Event.t()]
  def to_chart_events(self = %__MODULE__{}) do
    track_data =
      self
      |> find_intervals_with_status([:red_flag, :safety_car, :virtual_safety_car])
      |> Enum.reverse()
      |> Enum.map(fn interval ->
        %{
          ts_from: (if interval.starts_at, do: DateTime.to_unix(interval.starts_at)),
          ts_to: (if interval.ends_at, do: DateTime.to_unix(interval.ends_at)),
          # Add margin to the start and end of the interval to make it visually clearer which laps were affected
          lap_from: (if interval.status == :red_flag, do: interval.start_lap - 0.25),
          lap_to: (if interval.end_lap, do: interval.end_lap + 0.25),
          status: humanize_status(interval),
          type:
            case interval.status do
              :red_flag -> "instant"
              _ -> "interval"
            end
        }
      end)

    payload = %{dataset: "track_data", data: track_data}
    e = Event.new(:chart_data_replace, :track_status_data, payload)
    [e]
  end

  @spec humanize_status(interval()) :: String.t()
  def humanize_status(interval) do
    case interval.status do
      :all_clear -> "Clear"
      :yellow_flag -> "Yellow"
      :safety_car -> "SC"
      :red_flag -> "Red Flag"
      :virtual_safety_car -> "VSC"
      x -> Atom.to_string(x)
    end
  end

  defp maybe_end_previous_interval([last | rest], lap_number, timestamp) do
    last =
      if last.ends_at == nil do
        %{last | ends_at: timestamp, end_lap: lap_number}
      else
        last
      end

    [last | rest]
  end

  defp maybe_end_previous_interval(rest, _lap_number, _timestamp) do
    rest
  end
end
