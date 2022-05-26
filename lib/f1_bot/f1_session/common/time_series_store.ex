defmodule F1Bot.F1Session.Common.TimeSeriesStore do
  @moduledoc """
  Generic storage for time-series information such as car telemetry.
  """
  use TypedStruct
  alias Timex.Duration

  typedstruct do
    field(:data, [any()], default: [])
  end

  def new() do
    %__MODULE__{}
  end

  def push_data(
        self = %__MODULE__{data: data},
        sample = %{timestamp: %DateTime{}}
      ) do
    %{self | data: [sample | data]}
  end

  def find_samples_between(
        _self = %__MODULE__{data: data},
        from_ts = %DateTime{},
        to_ts = %DateTime{}
      ) do
    data
    |> Enum.filter(fn %{timestamp: ts} ->
      Timex.diff(ts, from_ts, :microseconds) >= 0 and
        Timex.diff(ts, to_ts, :microseconds) <= 0
    end)
    |> Enum.reverse()
  end

  def find_min_sample_around_ts(
        self = %__MODULE__{},
        ts = %DateTime{},
        window_ms,
        sample_cost_fn
      )
      when is_function(sample_cost_fn, 1) do
    delta = Duration.from_milliseconds(window_ms)

    from_ts = Timex.subtract(ts, delta)
    to_ts = Timex.add(ts, delta)

    result =
      self
      |> find_samples_between(from_ts, to_ts)
      |> Enum.min_by(sample_cost_fn, nil)

    case result do
      nil -> {:error, :empty}
      sample -> {:ok, sample}
    end
  end
end
