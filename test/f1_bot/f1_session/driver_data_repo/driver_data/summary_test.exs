defmodule F1Bot.F1Session.DriverDataRepo.DriverData.SummaryTest do
  use ExUnit.Case, async: true

  alias F1Bot.F1Session.TrackStatusHistory

  alias F1Bot.F1Session.DriverDataRepo.{
    DriverData,
    DriverData.Summary,
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
      tyres_changed: true
    }
  end

  def generate_lap(lap_number, time_sec, sectors \\ nil) do
    %Lap{
      number: lap_number,
      time: duration(time_sec),
      timestamp: nil,
      sectors: sectors
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
      data: [
        generate_lap(1, 1000, generate_sectors(nil, 60, 70)),
        generate_lap(2, 80, generate_sectors(nil, 20, nil)),
        generate_lap(3, 90, generate_sectors(40, 25, nil)),
        generate_lap(4, 100, generate_sectors(40, nil, 50)),
        generate_lap(5, 1000, generate_sectors(nil, 80, 90)),
        generate_lap(6, 80, generate_sectors(nil, nil, 30)),
        generate_lap(7, 95, generate_sectors(30, 20, nil)),
        generate_lap(8, 95, generate_sectors(40, 10, nil)),
        generate_lap(9, 130, generate_sectors(60, 40, 30)),
        generate_lap(10, 1000, generate_sectors(nil, 90, 90)),
        generate_lap(11, 70, generate_sectors(50, nil, 10)),
        generate_lap(12, 90, generate_sectors(20, 40, 30)),
        generate_lap(13, 80, generate_sectors(nil, nil, 50)),
        generate_lap(14, 60, generate_sectors(50, nil, 50))
      ]
    }

    driver_data = %DriverData{
      number: 1,
      stints: stints,
      laps: laps,
      top_speed: 333,
      fastest_lap: duration(73)
    }

    expected_summary = %{
      stints: [
        %{
          number: 1,
          lap_start: 1,
          lap_end: 4,
          compound: Enum.at(stints.data, 0) |> Map.fetch!(:compound),
          tyre_age: Enum.at(stints.data, 0) |> Map.fetch!(:age),
          average_time: duration(90),
          fastest_time: duration(80),
          timed_laps: 3
        },
        %{
          number: 2,
          lap_start: 5,
          lap_end: 9,
          compound: Enum.at(stints.data, 1) |> Map.fetch!(:compound),
          tyre_age: Enum.at(stints.data, 1) |> Map.fetch!(:age),
          average_time: duration(100),
          fastest_time: duration(80),
          timed_laps: 4
        },
        %{
          number: 3,
          lap_start: 10,
          lap_end: 14,
          compound: Enum.at(stints.data, 2) |> Map.fetch!(:compound),
          tyre_age: Enum.at(stints.data, 2) |> Map.fetch!(:age),
          average_time: duration(75),
          fastest_time: duration(60),
          timed_laps: 4
        }
      ],
      top_speed: driver_data.top_speed,
      fastest_lap: driver_data.fastest_lap,
      fastest_sectors: %{
        1 => duration(20),
        2 => duration(10),
        3 => duration(10),
        :ideal_lap => duration(40)
      }
    }

    track_status_hist = TrackStatusHistory.new()
    actual_summary = Summary.generate(driver_data, track_status_hist)

    assert actual_summary == expected_summary
  end
end
