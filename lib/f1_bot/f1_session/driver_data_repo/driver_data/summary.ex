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

  alias F1Bot.F1Session.TrackStatusHistory

  def generate(data = %DriverData{}, track_status_hist = %TrackStatusHistory{}) do
    stints = stints(data, track_status_hist)
    stats = aggregate_stats(data, stints)

    %{
      stints: stints,
      stats: stats
    }
  end

  defp stints(data, track_status_hist) do
    stints =
      data.stints.data
      |> Enum.sort_by(fn %Stint{number: n} -> n end, :asc)

    laps =
      data.laps.data
      |> Stream.filter(fn %Lap{number: n} -> n != nil end)
      # |> Stream.filter(fn %Lap{time: t} -> t != nil end)
      |> Enum.sort_by(fn %Lap{number: n} -> n end, :asc)

    neutralized_intervals =
      track_status_hist
      |> TrackStatusHistory.find_intervals_with_status([
        :virtual_safety_car,
        :safety_car,
        :red_flag
      ])

    process_stints([], stints, laps, neutralized_intervals)
    |> Enum.reverse()
  end

  defp process_stints(
         acc,
         _stints = [stint, next_stint | rest],
         laps,
         neutralized_intervals
       ) do
    # TODO: Possibly add sanity checks that next_stint.number is stint.number + 1 (in case of missing data)
    processed = analyze_stint(stint, next_stint, laps, neutralized_intervals)
    acc = [processed | acc]
    process_stints(acc, [next_stint | rest], laps, neutralized_intervals)
  end

  defp process_stints(acc, _stints = [stint], laps, neutralized_intervals) do
    processed = analyze_stint(stint, nil, laps, neutralized_intervals)
    [processed | acc]
  end

  defp process_stints(acc, _stints = [], _laps, _neutralized_intervals) do
    acc
  end

  defp analyze_stint(stint = %Stint{}, next_stint, laps, neutralized_intervals)
       when is_struct(next_stint, Stint) or is_nil(next_stint) do
    last_recorded_lap = laps |> List.last()

    lap_end =
      cond do
        next_stint != nil ->
          next_stint.lap_number - 1

        last_recorded_lap != nil ->
          last_recorded_lap
          |> Map.fetch!(:number)
          |> max(stint.lap_number)

        true ->
          stint.lap_number
      end

    # Keep outlap for now to determine stint start time
    timed_laps_start = stint.lap_number

    # Keep inlap
    timed_laps_end = lap_end

    relevant_laps =
      find_relevant_laps(
        laps,
        timed_laps_start,
        timed_laps_end,
        neutralized_intervals
      )

    # Remove outlap and determine stint start time
    {stint_start_time, relevant_laps} =
      case relevant_laps do
        [outlap | relevant_laps] ->
          start_time = stint.timestamp || outlap.timestamp
          {start_time, relevant_laps}

        [] ->
          {stint.timestamp, []}
      end

    %{
      number: stint.number,
      compound: stint.compound,
      tyre_age: stint.age,
      start_time: stint_start_time,
      lap_start: stint.lap_number,
      lap_end: lap_end,
      timed_laps: length(relevant_laps),
      stats: find_lap_times(relevant_laps)
    }
  end

  defp find_relevant_laps(laps, min_lap, max_lap, neutralized_intervals) do
    laps
    |> Stream.filter(fn lap = %Lap{} ->
      n = lap.number
      n != nil and n >= min_lap and n <= max_lap
    end)
    |> Stream.reject(fn lap = %Lap{} ->
      # Remove what is likely to be an outlap after a red flag
      lap.sectors == nil and lap.time != nil and Timex.Duration.to_seconds(lap.time) > 180
    end)
    |> Stream.reject(&Lap.is_neutralized?(&1, neutralized_intervals))
    |> Enum.sort_by(fn %Lap{number: number} -> number end, :asc)
  end

  defp find_lap_times(relevant_laps) do
    lap_stats =
      relevant_laps
      |> Enum.map(fn %Lap{time: time} -> time end)
      |> Enum.reject(&(&1 == nil))
      |> calculate_stats_for_times()

    s1_stats =
      relevant_laps
      |> Enum.map(fn %Lap{sectors: sectors} -> sectors[1][:time] end)
      |> Enum.reject(&(&1 == nil))
      |> calculate_stats_for_times()

    s2_stats =
      relevant_laps
      |> Enum.map(fn %Lap{sectors: sectors} -> sectors[2][:time] end)
      |> Enum.reject(&(&1 == nil))
      |> calculate_stats_for_times()

    s3_stats =
      relevant_laps
      |> Enum.map(fn %Lap{sectors: sectors} -> sectors[3][:time] end)
      |> Enum.reject(&(&1 == nil))
      |> calculate_stats_for_times()

    %{
      lap_time: lap_stats,
      s1_time: s1_stats,
      s2_time: s2_stats,
      s3_time: s3_stats
    }
  end

  defp calculate_stats_for_times(times) do
    {time_sum_ms, n_times, min_time} =
      times
      |> Enum.reduce({nil, 0, nil}, fn t, {time_sum_ms, n_times, min_time} ->
        min_time =
          if min_time == nil or Timex.Duration.diff(t, min_time, :milliseconds) < 0 do
            t
          else
            min_time
          end

        {time_sum, n_times} =
          cond do
            t == nil ->
              {time_sum_ms, n_times}

            time_sum_ms == nil and n_times == 0 ->
              t_ms = Timex.Duration.to_milliseconds(t)
              {t_ms, 1}

            true ->
              t_ms = Timex.Duration.to_milliseconds(t)
              {time_sum_ms + t_ms, n_times + 1}
          end

        {time_sum, n_times, min_time}
      end)

    average_time =
      if n_times > 0 do
        (time_sum_ms / n_times)
        |> round()
        |> Timex.Duration.from_milliseconds()
      else
        nil
      end

    %{
      average: average_time,
      fastest: min_time
    }
  end

  defp aggregate_stats(data, stints) do
    fastest_s1 =
      stints
      |> Enum.map(& &1.stats.s1_time.fastest)
      |> Enum.reject(&(&1 == nil))
      |> Enum.min_by(&Timex.Duration.to_milliseconds/1, fn -> nil end)

    fastest_s2 =
      stints
      |> Enum.map(& &1.stats.s2_time.fastest)
      |> Enum.reject(&(&1 == nil))
      |> Enum.min_by(&Timex.Duration.to_milliseconds/1, fn -> nil end)

    fastest_s3 =
      stints
      |> Enum.map(& &1.stats.s3_time.fastest)
      |> Enum.reject(&(&1 == nil))
      |> Enum.min_by(&Timex.Duration.to_milliseconds/1, fn -> nil end)

    theoretical_fl =
      if nil in [fastest_s1, fastest_s2, fastest_s3] do
        nil
      else
        fastest_s1
        |> Timex.Duration.add(fastest_s2)
        |> Timex.Duration.add(fastest_s3)
      end

    fastest_lap =
      stints
      |> Enum.map(& &1.stats.lap_time.fastest)
      |> Enum.reject(&(&1 == nil))
      |> Enum.min_by(&Timex.Duration.to_milliseconds/1, fn -> nil end)

    %{
      lap_time: %{
        fastest: fastest_lap,
        theoretical: theoretical_fl
      },
      s1_time: %{
        fastest: fastest_s1
      },
      s2_time: %{
        fastest: fastest_s2
      },
      s3_time: %{
        fastest: fastest_s3
      },
      top_speed: data.top_speed
    }
  end
end
