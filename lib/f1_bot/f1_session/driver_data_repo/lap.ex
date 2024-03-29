defmodule F1Bot.F1Session.DriverDataRepo.Lap do
  @moduledoc """
  Holds information about a single lap.
  """
  use TypedStruct

  alias F1Bot.F1Session.DriverDataRepo.{Stints, Sector}
  alias F1Bot.F1Session.TrackStatusHistory

  @type sector_map :: %{
          1 => Sector.t() | nil,
          2 => Sector.t() | nil,
          3 => Sector.t() | nil
        }

  typedstruct do
    @typedoc "Lap information"

    field(:number, pos_integer())
    field(:time, Timex.Duration.t())
    field(:timestamp, DateTime.t())

    field(:sectors, sector_map(),
      default: %{1 => nil, 2 => nil, 3 => nil}
    )

    field(:is_outlier, boolean())
    field(:is_valid, boolean(), default: true)
    # TODO: Not implemened yet
    field(:is_deleted, boolean(), default: false)
    field(:top_speed, pos_integer(), default: 0)
  end

  def new(args) when is_list(args) do
    struct!(__MODULE__, args)
  end

  @spec is_neutralized?(t(), [TrackStatusHistory.interval()]) :: boolean()
  def is_neutralized?(lap = %__MODULE__{}, neutralized_intervals) do
    if lap.time == nil or lap.timestamp == nil do
      false
    else
      lap_start = Timex.subtract(lap.timestamp, lap.time)
      lap_end = lap.timestamp

      Enum.any?(neutralized_intervals, fn %{starts_at: starts_at, ends_at: ends_at} ->
        # Add a margin for drivers to return to racing speed
        ends_at =
          if ends_at == nil do
            nil
          else
            Timex.add(ends_at, Timex.Duration.from_seconds(5))
          end

        started_during_neutral = F1Bot.Time.between?(lap_start, starts_at, ends_at)
        ended_during_neutral = F1Bot.Time.between?(lap_end, starts_at, ends_at)
        short_neutral_during_lap = F1Bot.Time.between?(starts_at, lap_start, lap_end)

        started_during_neutral or ended_during_neutral or short_neutral_during_lap
      end)
    end
  end

  @spec is_outlap_after_red_flag?(t()) :: boolean()
  def is_outlap_after_red_flag?(lap = %__MODULE__{}) do
    lap.sectors == nil and lap.time != nil and Timex.Duration.to_seconds(lap.time) > 180
  end

  @spec is_inlap?(t(), Stints.t()) :: boolean()
  def is_inlap?(lap = %__MODULE__{}, stints = %Stints{}) do
    inlaps =
      stints.data
      |> Enum.map(&(&1.lap_number - 1))

    lap.number in inlaps
  end

  @spec is_outlap?(t(), Stints.t()) :: boolean()
  def is_outlap?(lap = %__MODULE__{}, stints = %Stints{}) do
    outlaps =
      stints.data
      |> Enum.map(& &1.lap_number)

    lap.number in outlaps
  end
end
