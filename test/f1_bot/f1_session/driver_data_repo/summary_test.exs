defmodule F1Bot.F1Session.DriverDataRepo.SummaryTest do
  use ExUnit.Case, async: true

  alias F1Bot.F1Session.DriverDataRepo.BestStats
  alias F1Bot.F1Session.TrackStatusHistory

  alias F1Bot.F1Session.DriverDataRepo.{
    DriverData,
    Summary,
    Laps,
    Lap,
    Stints,
    Stint
  }

  def duration(_seconds = nil), do: nil
  def duration(seconds), do: Timex.Duration.from_seconds(seconds)

  def generate_stint(stint_number, lap_number) do
    %Stint{
      number: stint_number,
      lap_number: lap_number,
      compound: :soft,
      age: 0,
      total_laps: 0,
      tyres_changed: true,
      timestamp: nil
    }
  end

  def generate_lap(lap_number, time_sec, sectors \\ nil) do
    %Lap{
      number: lap_number,
      time: duration(time_sec),
      timestamp: nil,
      sectors: sectors,
      is_outlier: false,
      is_valid: true,
      is_deleted: false
    }
  end

  def generate_sectors(s1_sec, s2_sec, s3_sec) do
    %{
      1 => %{time: duration(s1_sec)},
      2 => %{time: duration(s2_sec)},
      3 => %{time: duration(s3_sec)}
    }
  end

  test "correctly generates stint summary" do
    stints = %Stints{
      data: [
        generate_stint(1, 1),
        generate_stint(2, 5),
        generate_stint(3, 10)
      ]
    }

    laps = %Laps{
      data:
        [
          generate_lap(1, 1000, generate_sectors(nil, 60, 70)),
          generate_lap(2, 80, generate_sectors(nil, 20, nil)),
          generate_lap(3, 90, generate_sectors(40, 25, nil)),
          generate_lap(4, 100, generate_sectors(30, nil, 50)),
          generate_lap(5, 1000, generate_sectors(nil, 80, 90)),
          generate_lap(6, 80, generate_sectors(nil, nil, 30)),
          generate_lap(7, 95, generate_sectors(30, 20, nil)),
          generate_lap(8, 95, generate_sectors(40, 10, nil)),
          generate_lap(9, 130, generate_sectors(50, 30, 30)),
          generate_lap(10, 1000, generate_sectors(nil, 90, 90)),
          generate_lap(11, 70, generate_sectors(50, nil, 10)),
          generate_lap(12, 90, generate_sectors(20, 40, 30)),
          generate_lap(13, 80, generate_sectors(nil, nil, 50)),
          generate_lap(14, 60, generate_sectors(50, nil, 50))
        ]
        |> Enum.map(fn lap -> {lap.number, lap} end)
        |> Enum.into(%{})
    }

    pb_stats = Laps.personal_best_stats(laps)

    driver_data = %DriverData{
      number: 1,
      stints: stints,
      laps: laps
    }

    expected_summary = %{
      stints: [
        %{
          number: 1,
          lap_start: 1,
          lap_end: 4,
          start_time: nil,
          compound: Enum.at(stints.data, 0) |> Map.fetch!(:compound),
          tyre_age: Enum.at(stints.data, 0) |> Map.fetch!(:age),
          timed_laps: 2,
          stats: %{
            lap_time: %{
              fastest: %{value: duration(80), best: nil},
              # Lap 1 is excluded as outlap and lap 4 is excluded as inlap
              average: %{value: duration(85), best: nil}
            },
            s1_time: %{
              fastest: %{value: duration(40), best: nil},
              average: %{value: duration(40), best: nil}
            },
            s2_time: %{
              fastest: %{value: duration(20), best: nil},
              average: %{value: duration(22.5), best: nil}
            },
            s3_time: %{
              fastest: %{value: nil, best: nil},
              average: %{value: nil, best: nil}
            }
          }
        },
        %{
          number: 2,
          lap_start: 5,
          lap_end: 9,
          start_time: nil,
          compound: Enum.at(stints.data, 1) |> Map.fetch!(:compound),
          tyre_age: Enum.at(stints.data, 1) |> Map.fetch!(:age),
          timed_laps: 3,
          stats: %{
            lap_time: %{
              fastest: %{value: duration(80), best: nil},
              # Lap 5 is excluded as outlap and lap 9 is excluded as inlap
              average: %{value: duration(90), best: nil}
            },
            s1_time: %{
              fastest: %{value: duration(30), best: nil},
              average: %{value: duration(35), best: nil}
            },
            s2_time: %{
              fastest: %{value: duration(10), best: :overall},
              average: %{value: duration(15), best: nil}
            },
            s3_time: %{
              fastest: %{value: duration(30), best: nil},
              average: %{value: duration(30), best: nil}
            }
          }
        },
        %{
          number: 3,
          lap_start: 10,
          lap_end: 14,
          start_time: nil,
          compound: Enum.at(stints.data, 2) |> Map.fetch!(:compound),
          tyre_age: Enum.at(stints.data, 2) |> Map.fetch!(:age),
          timed_laps: 4,
          stats: %{
            lap_time: %{
              fastest: %{value: duration(60), best: :overall},
              # Lap 10 is excluded as outlap
              average: %{value: duration(75), best: nil}
            },
            s1_time: %{
              fastest: %{value: duration(20), best: :overall},
              average: %{value: duration(40), best: nil}
            },
            s2_time: %{
              fastest: %{value: duration(40), best: nil},
              average: %{value: duration(40), best: nil}
            },
            s3_time: %{
              fastest: %{value: duration(10), best: :overall},
              average: %{value: duration(35), best: nil}
            }
          }
        }
      ],
      stats: %{
        lap_time: %{
          fastest: %{value: duration(60), best: :overall},
          theoretical: %{value: duration(40), best: nil}
        },
        s1_time: %{
          fastest: %{value: duration(20), best: :overall}
        },
        s2_time: %{
          fastest: %{value: duration(10), best: :overall}
        },
        s3_time: %{
          fastest: %{value: duration(10), best: :overall}
        },
        top_speed: %{value: nil, best: nil}
      },
      driver_number: 1,
      has_best_overall: true
    }

    track_status_hist = TrackStatusHistory.new()

    best_stast = %BestStats{
      personal_best: %{} |> Map.put(driver_data.number, pb_stats),
      fastest_sectors: pb_stats.sectors_ms,
      fastest_lap_ms: pb_stats.lap_time_ms,
      top_speed: 99999
    }

    actual_summary = Summary.generate(driver_data, track_status_hist, best_stast)

    assert actual_summary == expected_summary
  end
end
