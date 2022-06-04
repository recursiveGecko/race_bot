defmodule F1Bot.F1Session.DriverDataRepo.DriverData.Summary do
  @moduledoc """
  Generates a driver summary that includes fastest lap, top speed and summarized
  stint information (stint laps, tyre compound, average & minimum lap time)
  """
  alias F1Bot.F1Session.DriverDataRepo.{
    DriverData,
    Lap,
    Stint
  }

  def generate(data = %DriverData{}) do
    %{
      stints: stints(data),
      fastest_lap: data.fastest_lap,
      top_speed: data.top_speed
    }
  end

  defp stints(data = %DriverData{}) do
    stints =
      data.stints.data
      |> Enum.sort_by(fn %Stint{number: n} -> n end, :asc)

    laps =
      data.laps.data
      |> Stream.filter(fn %Lap{number: n} -> n != nil end)
      |> Stream.filter(fn %Lap{time: t} -> t != nil end)
      |> Enum.sort_by(fn %Lap{number: n} -> n end, :asc)

    process_stints([], stints, laps)
    |> Enum.reverse()
  end

  defp process_stints(acc, _stints = [stint, next_stint | rest], laps) do
    # TODO: Possibly add sanity checks that next_stint.number is stint.number + 1 (in case of missing data)
    processed = analyze_stint(stint, next_stint, laps)
    acc = [processed | acc]
    process_stints(acc, [next_stint | rest], laps)
  end

  defp process_stints(acc, _stints = [stint], laps) do
    processed = analyze_stint(stint, nil, laps)
    [processed | acc]
  end

  defp process_stints(acc, _stints = [], _laps) do
    acc
  end

  defp analyze_stint(stint = %Stint{}, next_stint, laps)
       when is_struct(next_stint, Stint) or is_nil(next_stint) do
    lap_end =
      if next_stint == nil do
        laps |> List.last() |> Map.fetch!(:number)
      else
        next_stint.lap_number - 1
      end

    # Remove outlap
    timed_laps_start = stint.lap_number + 1

    # Keep inlap
    timed_laps_end = lap_end

    relevant_laps = find_relevant_laps(laps, timed_laps_start, timed_laps_end)

    %{avg: avg_time, min: min_time} = find_lap_times(relevant_laps)

    %{
      number: stint.number,
      compound: stint.compound,
      tyre_age: stint.age,
      lap_start: stint.lap_number,
      lap_end: lap_end,
      timed_laps: length(relevant_laps),
      average_time: avg_time,
      fastest_time: min_time
    }
  end

  defp find_relevant_laps(laps, min_lap, max_lap) do
    laps
    |> Stream.filter(fn lap = %Lap{} ->
      n = lap.number
      n != nil and n >= min_lap and n <= max_lap
    end)
    |> Stream.filter(fn lap = %Lap{} ->
      lap.time != nil
    end)
    |> Enum.sort_by(fn %Lap{time: time} -> time end, :asc)
  end

  defp find_lap_times(relevant_laps) do
    {time_sum_ms, min_time} =
      relevant_laps
      |> Enum.reduce({nil, nil}, fn lap = %Lap{}, {time_sum_ms, min_time} ->
        t = lap.time

        min_time =
          if min_time == nil or Timex.Duration.diff(t, min_time, :milliseconds) < 0 do
            t
          else
            min_time
          end

        t_ms = Timex.Duration.to_milliseconds(t)

        time_sum =
          if time_sum_ms == nil do
            t_ms
          else
            time_sum_ms + t_ms
          end

        {time_sum, min_time}
      end)

    num_relevant = length(relevant_laps)

    average_time =
      if num_relevant > 0 do
        (time_sum_ms / num_relevant)
        |> round()
        |> Timex.Duration.from_milliseconds()
      else
        nil
      end

    %{
      avg: average_time,
      min: min_time
    }
  end
end
