defmodule F1Bot.F1Session.DriverDataRepo.BestStatsTest do
  use ExUnit.Case, async: true

  alias F1Bot.F1Session.DriverDataRepo.BestStats

  alias F1Bot.F1Session.DriverDataRepo.DriverData.{
    EndOfLapResult,
    EndOfSectorResult
  }

  def duration(seconds), do: Timex.Duration.from_seconds(seconds)

  test "push_end_of_lap_result/2 updates lap time and top speed when starting from nil" do
    eol_result = %EndOfLapResult{
      driver_number: 1,
      lap_time: duration(95),
      lap_delta: duration(5),
      is_fastest_lap: false,
      lap_top_speed: 200,
      speed_delta: -5,
      is_top_speed: false
    }

    {best_stats, _events} =
      %BestStats{}
      |> BestStats.push_end_of_lap_result(eol_result)

    assert best_stats.fastest_lap == eol_result.lap_time
    assert best_stats.top_speed == eol_result.lap_top_speed
  end

  test "push_end_of_lap_result/2 updates lap time and top speed when they're records" do
    eol_result = %EndOfLapResult{
      driver_number: 1,
      lap_time: duration(95),
      lap_delta: duration(5),
      is_fastest_lap: false,
      lap_top_speed: 200,
      speed_delta: -5,
      is_top_speed: false
    }

    {best_stats, _events} =
      %BestStats{top_speed: 50, fastest_lap: duration(500)}
      |> BestStats.push_end_of_lap_result(eol_result)

    assert best_stats.fastest_lap == eol_result.lap_time
    assert best_stats.top_speed == eol_result.lap_top_speed
  end

  test "push_end_of_lap_result/2 doesn't update lap time and top speed when they're not records" do
    eol_result = %EndOfLapResult{
      driver_number: 1,
      lap_time: duration(95),
      lap_delta: duration(5),
      is_fastest_lap: false,
      lap_top_speed: 200,
      speed_delta: -5,
      is_top_speed: false
    }

    {best_stats, _events} =
      %BestStats{top_speed: 9999, fastest_lap: duration(1)}
      |> BestStats.push_end_of_lap_result(eol_result)

    assert best_stats.fastest_lap == duration(1)
    assert best_stats.top_speed == 9999
  end

  test "push_end_of_lap_result/2 doesn't create events when they're not records" do
    eol_result = %EndOfLapResult{
      driver_number: 1,
      lap_time: duration(95),
      lap_delta: duration(5),
      is_fastest_lap: false,
      lap_top_speed: 200,
      speed_delta: -5,
      is_top_speed: false
    }

    {_best_stats, events} =
      %BestStats{top_speed: 9999, fastest_lap: duration(1)}
      |> BestStats.push_end_of_lap_result(eol_result)

    assert events == []
  end

  test "push_end_of_lap_result/2 creates overall best lap time events" do
    eol_result = %EndOfLapResult{
      driver_number: 1,
      lap_time: duration(95),
      lap_delta: duration(5),
      is_fastest_lap: true,
      lap_top_speed: 200,
      speed_delta: -5,
      is_top_speed: false
    }

    {_best_stats, events} =
      %BestStats{top_speed: 9999, fastest_lap: duration(100)}
      |> BestStats.push_end_of_lap_result(eol_result)

    expected_time = eol_result.lap_time
    expected_delta = Timex.Duration.diff(duration(95), duration(100))

    assert match?(
             [
               %{
                 payload: %{
                   type: :overall,
                   lap_time: ^expected_time,
                   lap_delta: ^expected_delta
                 }
               }
             ],
             events
           )
  end

  test "push_end_of_lap_result/2 creates overall best top speed events" do
    eol_result = %EndOfLapResult{
      driver_number: 1,
      lap_time: duration(95),
      lap_delta: duration(5),
      is_fastest_lap: false,
      lap_top_speed: 200,
      speed_delta: -5,
      is_top_speed: true
    }

    {_best_stats, events} =
      %BestStats{top_speed: 1, fastest_lap: duration(1)}
      |> BestStats.push_end_of_lap_result(eol_result)

    assert match?([%{payload: %{type: :overall, speed: 200, speed_delta: 199}}], events)
  end

  test "push_end_of_lap_result/2 creates personal best lap time events" do
    eol_result = %EndOfLapResult{
      driver_number: 1,
      lap_time: duration(95),
      lap_delta: duration(-5),
      is_fastest_lap: true,
      lap_top_speed: 200,
      speed_delta: -5,
      is_top_speed: false
    }

    {_best_stats, events} =
      %BestStats{top_speed: 9999, fastest_lap: duration(1)}
      |> BestStats.push_end_of_lap_result(eol_result)

    expected_time = eol_result.lap_time
    expected_delta = eol_result.lap_delta

    assert match?(
             [
               %{
                 payload: %{
                   type: :personal,
                   lap_time: ^expected_time,
                   lap_delta: ^expected_delta
                 }
               }
             ],
             events
           )
  end

  test "push_end_of_lap_result/2 creates personal best top speed events" do
    eol_result = %EndOfLapResult{
      driver_number: 1,
      lap_time: duration(95),
      lap_delta: duration(5),
      is_fastest_lap: false,
      lap_top_speed: 200,
      speed_delta: -5,
      is_top_speed: true
    }

    {_best_stats, events} =
      %BestStats{top_speed: 9999, fastest_lap: duration(1)}
      |> BestStats.push_end_of_lap_result(eol_result)

    assert match?([%{payload: %{type: :personal, speed: 200, speed_delta: -5}}], events)
  end

  test "push_end_of_lap_result/2 doesn't explode on nil lap time and speed values" do
    eol_result = %EndOfLapResult{
      driver_number: 1,
      lap_time: nil,
      lap_delta: nil,
      is_fastest_lap: false,
      lap_top_speed: nil,
      speed_delta: nil,
      is_top_speed: false
    }

    {best_stats, events} =
      %BestStats{top_speed: 123, fastest_lap: duration(9999)}
      |> BestStats.push_end_of_lap_result(eol_result)

    assert best_stats.top_speed == 123
    assert best_stats.fastest_lap == duration(9999)
    assert events == []
  end

  test "push_end_of_sector_result/2 updates best sector times when starting from nil" do
    eos_result = %EndOfSectorResult{
      driver_number: 1,
      sector: 1,
      sector_time: duration(30)
    }

    {best_stats, _events} =
      %BestStats{}
      |> BestStats.push_end_of_sector_result(eos_result)

    assert best_stats.fastest_sectors[1] == eos_result.sector_time
  end

  test "push_end_of_sector_result/2 updates best sector times when they're improved" do
    eos_result = %EndOfSectorResult{
      driver_number: 1,
      sector: 2,
      sector_time: duration(25)
    }

    initial_sectors = %{
      1 => duration(999),
      2 => duration(999),
      3 => duration(999)
    }

    wanted_sectors = Map.put(initial_sectors, 2, duration(25))

    {best_stats, _events} =
      %BestStats{fastest_sectors: initial_sectors}
      |> BestStats.push_end_of_sector_result(eos_result)

    assert match?(^wanted_sectors, best_stats.fastest_sectors)
  end

  test "push_end_of_sector_result/2 creates overall best sector time events" do
    eos_result = %EndOfSectorResult{
      driver_number: 1,
      sector: 2,
      sector_time: duration(25)
    }

    initial_sectors = %{
      1 => duration(100),
      2 => duration(100),
      3 => duration(100)
    }

    expected_delta = duration(-75)

    {_best_stats, events} =
      %BestStats{fastest_sectors: initial_sectors}
      |> BestStats.push_end_of_sector_result(eos_result)

    assert match?(
             [
               %{payload: %{type: :overall, sector: 2, sector_delta: ^expected_delta}}
             ],
             events
           )
  end

  test "push_end_of_sector_result/2 doesn't explode on nil sector time" do
    eos_result = %EndOfSectorResult{
      driver_number: 1,
      sector: 1,
      sector_time: nil
    }

    {best_stats, _events} =
      %BestStats{}
      |> BestStats.push_end_of_sector_result(eos_result)

    assert best_stats.fastest_sectors[1] == nil
  end
end
