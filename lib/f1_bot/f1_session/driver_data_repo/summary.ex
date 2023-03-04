defmodule F1Bot.F1Session.DriverDataRepo.Summary do
  @moduledoc """
  Generates a driver summary that includes fastest lap, top speed and summarized
  stint information (stint laps, tyre compound, average & minimum lap time)
  """
  alias F1Bot.F1Session.DriverDataRepo.{
    PersonalBestStats,
    BestStats,
    DriverData,
    Lap,
    Stint
  }

  alias F1Bot.F1Session.TrackStatusHistory

  def generate(
        data = %DriverData{},
        track_status_hist = %TrackStatusHistory{},
        best_stats \\ BestStats.new()
      )
      when is_struct(best_stats, BestStats) do
    neutralized_intervals =
      track_status_hist
      |> TrackStatusHistory.find_intervals_with_status([
        :virtual_safety_car,
        :safety_car,
        :red_flag
      ])

    context = %{
      driver_number: data.number,
      neutralized_intervals: neutralized_intervals,
      best_stats: best_stats
    }

    stints = process_stints(data, context)
    {stats, has_best_overall} = aggregate_stats(context)

    %{
      driver_number: data.number,
      stints: stints,
      stats: stats,
      has_best_overall: has_best_overall
    }
  end

  def empty_summary() do
    data = DriverData.new(0)
    hist = TrackStatusHistory.new()
    generate(data, hist, BestStats.new())
  end

  defp process_stints(data, context) do
    stints =
      data.stints.data
      |> Enum.sort_by(fn stint -> stint.number end, :asc)

    laps =
      data.laps.data
      |> Map.values()
      |> Stream.filter(fn lap -> lap.number != nil end)
      |> Enum.sort_by(fn lap -> lap.number end, :asc)

    process_stints_in_pairs([], stints, laps, context)
    |> Enum.reverse()
  end

  defp process_stints_in_pairs(
         acc,
         _stints = [stint, next_stint | rest],
         laps,
         ctx
       ) do
    processed = analyze_stint_pair(stint, next_stint, laps, ctx)
    acc = [processed | acc]
    process_stints_in_pairs(acc, [next_stint | rest], laps, ctx)
  end

  defp process_stints_in_pairs(acc, _stints = [stint], laps, ctx) do
    processed = analyze_stint_pair(stint, nil, laps, ctx)
    [processed | acc]
  end

  defp process_stints_in_pairs(acc, _stints = [], _laps, _context) do
    acc
  end

  defp analyze_stint_pair(stint = %Stint{}, next_stint, laps, ctx)
       when is_struct(next_stint, Stint) or is_nil(next_stint) do
    # Remove outlap
    timed_laps_start = stint.lap_number + 1

    {stint_end_lap, timed_laps_end} =
      cond do
        next_stint != nil ->
          # Remove inlap
          inlap = next_stint.lap_number - 1
          {inlap, inlap - 1}

        laps != [] ->
          last_recorded_lap = List.last(laps)
          last_lap = max(last_recorded_lap.number, stint.lap_number)

          {last_lap, last_lap}

        true ->
          {stint.lap_number, stint.lap_number}
      end

    relevant_laps =
      find_relevant_laps(
        laps,
        timed_laps_start,
        timed_laps_end,
        ctx.neutralized_intervals
      )

    %{
      number: stint.number,
      compound: stint.compound,
      tyre_age: stint.age,
      start_time: stint.timestamp,
      lap_start: stint.lap_number,
      lap_end: stint_end_lap,
      timed_laps: length(relevant_laps),
      stats: analyze_laps(relevant_laps, ctx)
    }
  end

  defp find_relevant_laps(laps, min_lap, max_lap, neutralized_intervals) do
    laps
    |> Stream.filter(fn lap = %Lap{} ->
      n = lap.number
      n != nil and n >= min_lap and n <= max_lap
    end)
    |> Stream.reject(&Lap.is_outlap_after_red_flag?/1)
    |> Stream.reject(&Lap.is_neutralized?(&1, neutralized_intervals))
    |> Stream.reject(fn %Lap{is_outlier: outlier} -> !!outlier end)
    |> Enum.sort_by(fn %Lap{number: number} -> number end, :asc)
  end

  defp analyze_laps(relevant_laps, ctx) do
    lap_stats =
      relevant_laps
      |> Enum.map(fn %Lap{time: time} -> time end)
      |> analyze_times(ctx, :lap)

    s1 =
      relevant_laps
      |> extract_sector_times(1)
      |> analyze_times(ctx, :s1)

    s2 =
      relevant_laps
      |> extract_sector_times(2)
      |> analyze_times(ctx, :s2)

    s3 =
      relevant_laps
      |> extract_sector_times(3)
      |> analyze_times(ctx, :s3)

    %{
      lap_time: lap_stats,
      s1_time: s1,
      s2_time: s2,
      s3_time: s3
    }
  end

  defp aggregate_stats(ctx) do
    pb_stats = ctx.best_stats.personal_best[ctx.driver_number]

    if pb_stats == nil do
      nil_stat_val = wrap_with_best_indicator(nil, ctx, nil)

      stats = %{
        lap_time: %{
          fastest: nil_stat_val,
          theoretical: nil_stat_val
        },
        s1_time: %{
          fastest: nil_stat_val
        },
        s2_time: %{
          fastest: nil_stat_val
        },
        s3_time: %{
          fastest: nil_stat_val
        },
        top_speed: nil_stat_val
      }

      {stats, false}
    else
      s1 = pb_stats.sectors_ms[1]
      s2 = pb_stats.sectors_ms[2]
      s3 = pb_stats.sectors_ms[3]

      theoretical_fl_ms =
        if nil in [s1, s2, s3] do
          nil
        else
          s1 + s2 + s3
        end

      stats = %{
        lap_time: %{
          fastest: wrap_with_best_indicator(pb_stats.lap_time_ms, ctx, :lap),
          theoretical: wrap_with_best_indicator(theoretical_fl_ms, ctx, :theoretical_lap)
        },
        s1_time: %{
          fastest: wrap_with_best_indicator(s1, ctx, :s1)
        },
        s2_time: %{
          fastest: wrap_with_best_indicator(s2, ctx, :s2)
        },
        s3_time: %{
          fastest: wrap_with_best_indicator(s3, ctx, :s3)
        },
        top_speed: wrap_with_best_indicator(pb_stats.top_speed, ctx, :speed)
      }

      has_best_overall =
        :overall in [
          stats.lap_time.fastest.best,
          stats.lap_time.theoretical.best,
          stats.s1_time.fastest.best,
          stats.s2_time.fastest.best,
          stats.s3_time.fastest.best,
          stats.top_speed.best
        ]

      {stats, has_best_overall}
    end
  end

  # Calculate minimum and average values for a list of times,
  # and wrap them in a map with a `best` field indicating whether
  # the time is an overall best, personal best, or neither.
  # `ctx` is the context map containing `%BestStats{}`
  defp analyze_times(times, ctx, type) do
    non_nil_times =
      times
      |> Stream.filter(&(&1 != nil))
      |> Enum.map(&Timex.Duration.to_milliseconds/1)

    n_times = length(non_nil_times)

    time_sum_ms = Enum.sum(non_nil_times)
    min_time_ms = Enum.min(non_nil_times, fn -> nil end)

    average_time_ms =
      if n_times > 0 do
        (time_sum_ms / n_times)
        |> round()
      else
        nil
      end

    %{
      fastest: wrap_with_best_indicator(min_time_ms, ctx, type),
      average: wrap_with_best_indicator(average_time_ms, ctx, :none)
    }
  end

  defp extract_sector_times(laps, sector) do
    laps
    |> Stream.map(& &1.sectors[sector])
    |> Stream.filter(&(&1 != nil))
    |> Enum.map(& &1.time)
  end

  defp wrap_with_best_indicator(_time_ms = nil, _ctx, _type) do
    %{
      value: nil,
      best: nil
    }
  end

  defp wrap_with_best_indicator(time_ms, _ctx, _type) when not is_number(time_ms) do
    raise ArgumentError, "time_ms must be a number: #{inspect(time_ms)}"
  end

  defp wrap_with_best_indicator(time_ms, _ctx, _type = :none) do
    %{
      value: ms_to_duration(time_ms),
      best: nil
    }
  end

  defp wrap_with_best_indicator(speed, _ctx, _type = :speed) do
    %{
      value: speed,
      best: nil
    }
  end

  defp wrap_with_best_indicator(time_ms, _ctx, _type = :theoretical_lap) do
    %{
      value: ms_to_duration(time_ms),
      best: nil
    }
  end

  defp wrap_with_best_indicator(time_ms, ctx, type)
       when is_number(time_ms) and type in [:s1, :s2, :s3, :lap] do
    # Personal best value for this statistic
    pb_value = extract_pb_value(ctx.best_stats, ctx.driver_number, type)
    # Session best value for this statistic
    sb_value = extract_sb_value(ctx.best_stats, type)

    best_type =
      cond do
        sb_value != nil and time_ms == sb_value ->
          :overall

        pb_value != nil and time_ms == pb_value ->
          :personal

        true ->
          nil
      end

    %{
      value: ms_to_duration(time_ms),
      best: best_type
    }
  end

  defp extract_pb_value(%BestStats{personal_best: pb}, driver_number, type) do
    pb_stats = pb[driver_number]

    if pb_stats == nil do
      nil
    else
      do_extract_pb_value(pb_stats, type)
    end
  end

  defp do_extract_pb_value(pb_stats = %PersonalBestStats{}, _type = :s1),
    do: pb_stats.sectors_ms[1]

  defp do_extract_pb_value(pb_stats = %PersonalBestStats{}, _type = :s2),
    do: pb_stats.sectors_ms[2]

  defp do_extract_pb_value(pb_stats = %PersonalBestStats{}, _type = :s3),
    do: pb_stats.sectors_ms[3]

  defp do_extract_pb_value(pb_stats = %PersonalBestStats{}, _type = :lap),
    do: pb_stats.lap_time_ms

  defp extract_sb_value(best_stats = %BestStats{}, _type = :s1), do: best_stats.fastest_sectors[1]
  defp extract_sb_value(best_stats = %BestStats{}, _type = :s2), do: best_stats.fastest_sectors[2]
  defp extract_sb_value(best_stats = %BestStats{}, _type = :s3), do: best_stats.fastest_sectors[3]
  defp extract_sb_value(best_stats = %BestStats{}, _type = :lap), do: best_stats.fastest_lap_ms

  defp ms_to_duration(_ms = nil), do: nil
  defp ms_to_duration(ms) when is_number(ms), do: Timex.Duration.from_milliseconds(ms)
end
