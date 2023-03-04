defmodule F1Bot.F1Session.DriverDataRepo.BestStatsTest do
  use ExUnit.Case, async: true

  alias F1Bot.F1Session.DriverDataRepo.{BestStats, PersonalBestStats}

  def duration(seconds), do: Timex.Duration.from_seconds(seconds)

  test "push_personal_best_stats/2 updates lap time when starting from nil" do
    pb_stats = %PersonalBestStats{
      driver_number: 1,
      lap_time_ms: 80_000
    }

    {best_stats, events} =
      %BestStats{}
      |> BestStats.push_personal_best_stats(pb_stats)

    assert best_stats.fastest_lap_ms == pb_stats.lap_time_ms
    assert best_stats.personal_best[1] == pb_stats
    assert events != []
  end

  test "push_personal_best_stats/2 updates overall best lap time when it's not a record" do
    pb_stats = %PersonalBestStats{
      driver_number: 1,
      lap_time_ms: 80_000
    }

    {best_stats, events} =
      %BestStats{fastest_lap_ms: 999_000}
      |> BestStats.push_personal_best_stats(pb_stats)

    assert best_stats.fastest_lap_ms == pb_stats.lap_time_ms
    assert best_stats.personal_best[1] == pb_stats
    assert events != []
  end

  test "push_personal_best_stats/2 updates PB lap time when it's not a record" do
    pb_stats = %PersonalBestStats{
      driver_number: 1,
      lap_time_ms: 80_000
    }

    {best_stats, events} =
      %BestStats{
        fastest_lap_ms: 10_000,
        personal_best: %{1 => %PersonalBestStats{lap_time_ms: 999_000}}
      }
      |> BestStats.push_personal_best_stats(pb_stats)

    assert best_stats.fastest_lap_ms == 10_000
    assert best_stats.personal_best[1] == pb_stats
    assert events != []
  end

  test "push_personal_best_stats/2 doesn't update lap time data when it's not a record" do
    pb_stats = %PersonalBestStats{
      driver_number: 1,
      lap_time_ms: 999_000
    }

    {best_stats, events} =
      %BestStats{
        fastest_lap_ms: 10_000,
        personal_best: %{1 => %PersonalBestStats{lap_time_ms: 20_000}}
      }
      |> BestStats.push_personal_best_stats(pb_stats)

    assert best_stats.fastest_lap_ms == 10_000
    assert best_stats.personal_best[1] == pb_stats
    assert events == []
  end

  test "push_personal_best_stats/2 updates PB top speed when starting from nil" do
    pb_stats = %PersonalBestStats{
      driver_number: 1,
      top_speed: 999
    }

    {best_stats, events} =
      %BestStats{
        personal_best: %{}
      }
      |> BestStats.push_personal_best_stats(pb_stats)

    assert best_stats.top_speed == 999
    assert best_stats.personal_best[1] == pb_stats
    assert events != []
  end

  test "push_personal_best_stats/2 updates PB top speed when it's not a record" do
    pb_stats = %PersonalBestStats{
      driver_number: 1,
      top_speed: 999
    }

    {best_stats, events} =
      %BestStats{
        top_speed: 0,
        personal_best: %{1 => %PersonalBestStats{}}
      }
      |> BestStats.push_personal_best_stats(pb_stats)

    assert best_stats.top_speed == 999
    assert best_stats.personal_best[1] == pb_stats
    assert events != []
  end

  test "push_personal_best_stats/2 doesn't update PB top speed when they're not records" do
    pb_stats = %PersonalBestStats{
      driver_number: 1,
      top_speed: 10
    }

    {best_stats, events} =
      %BestStats{
        top_speed: 999,
        personal_best: %{1 => %PersonalBestStats{top_speed: 100}}
      }
      |> BestStats.push_personal_best_stats(pb_stats)

    assert best_stats.top_speed == 999
    assert best_stats.personal_best[1] == pb_stats
    assert events == []
  end

  test "push_personal_best_stats/2 updates sector times when starting from nil" do
    pb_stats = %PersonalBestStats{
      driver_number: 1,
      sectors_ms: %{
        1 => 10_000,
        2 => 20_000,
        3 => 30_000
      }
    }

    {best_stats, events} =
      %BestStats{}
      |> BestStats.push_personal_best_stats(pb_stats)

    assert best_stats.fastest_sectors == pb_stats.sectors_ms
    assert best_stats.personal_best[1] == pb_stats
    assert events != []
  end

  test "push_personal_best_stats/2 updates PB sector times when they're not records" do
    pb_stats = %PersonalBestStats{
      driver_number: 1,
      sectors_ms: %{
        1 => 10_000,
        2 => 20_000,
        3 => 30_000
      }
    }

    {best_stats, events} =
      %BestStats{
        fastest_sectors: %{
          1 => 1_000,
          2 => 1_000,
          3 => 1_000
        },
        personal_best: %{1 => %PersonalBestStats{}}
      }
      |> BestStats.push_personal_best_stats(pb_stats)

    assert best_stats.fastest_sectors[1] == 1_000
    assert best_stats.fastest_sectors[2] == 1_000
    assert best_stats.fastest_sectors[3] == 1_000
    assert best_stats.personal_best[1] == pb_stats
    assert events != []
  end

  test "push_personal_best_stats/2 doesn't update sector times when they're not records" do
    pb_stats = %PersonalBestStats{
      driver_number: 1,
      sectors_ms: %{
        1 => 10_000,
        2 => 20_000,
        3 => 30_000
      }
    }

    {best_stats, events} =
      %BestStats{
        fastest_sectors: %{
          1 => 1_000,
          2 => 1_000,
          3 => 1_000
        },
        personal_best: %{
          1 => %PersonalBestStats{
            sectors_ms: %{
              1 => 5_000,
              2 => 5_000,
              3 => 5_000
            }
          }
        }
      }
      |> BestStats.push_personal_best_stats(pb_stats)

    assert best_stats.fastest_sectors[1] == 1_000
    assert best_stats.fastest_sectors[2] == 1_000
    assert best_stats.fastest_sectors[3] == 1_000
    assert best_stats.personal_best[1] == pb_stats
    assert events == []
  end
end
