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
    %{
      stints: stints(data, track_status_hist),
      fastest_lap: data.fastest_lap,
      top_speed: data.top_speed,
      fastest_sectors: find_fastest_sectors(data)
    }
  end

  defp stints(data, track_status_hist) do
    stints =
      data.stints.data
      |> Enum.sort_by(fn %Stint{number: n} -> n end, :asc)

    laps =
      data.laps.data
      |> Stream.filter(fn %Lap{number: n} -> n != nil end)
      |> Stream.filter(fn %Lap{time: t} -> t != nil end)
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

    relevant_laps =
      find_relevant_laps(
        laps,
        timed_laps_start,
        timed_laps_end,
        neutralized_intervals
      )

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

  defp find_relevant_laps(laps, min_lap, max_lap, neutralized_intervals) do
    laps
    |> Stream.filter(fn lap = %Lap{} ->
      n = lap.number
      n != nil and n >= min_lap and n <= max_lap
    end)
    |> Stream.filter(fn lap = %Lap{} ->
      lap.time != nil
    end)
    |> Stream.reject(fn lap = %Lap{} ->
      # Remove what is likely to be an outlap after a red flag
      lap.sectors == nil and lap.time != nil and Timex.Duration.to_seconds(lap.time) > 240
    end)
    |> Stream.reject(&Lap.is_neutralized?(&1, neutralized_intervals))
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

  defp find_fastest_sectors(_data = %DriverData{laps: laps}) do
    min_sector_times =
      for sector <- [1, 2, 3] do
        times =
          for l <- laps.data,
              l.sectors[sector][:time] != nil do
            l.sectors[sector][:time]
          end

        fastest_sector_time = Enum.min_by(times, &Timex.Duration.to_milliseconds/1, fn -> nil end)

        {sector, fastest_sector_time}
      end
      |> Enum.into(%{})

    ideal_lap =
      min_sector_times
      |> Map.values()
      |> Enum.reduce(Timex.Duration.zero(), fn time, acc ->
        if acc == nil or time == nil do
          nil
        else
          Timex.Duration.add(acc, time)
        end
      end)

    min_sector_times
    |> Map.put(:ideal_lap, ideal_lap)
  end
end
