defmodule F1Bot.F1Session.DriverDataRepo.DriverData.SummaryTest do
  use ExUnit.Case, async: true

  alias F1Bot.F1Session.DriverDataRepo.{
    DriverData,
    DriverData.Summary,
    Laps,
    Lap,
    Stints,
    Stint
  }

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

  def generate_lap(lap_number, time_sec) do
    %Lap{
      number: lap_number,
      time: Timex.Duration.from_seconds(time_sec),
      timestamp: nil
    }
  end

  test "correctly generates driver summary" do
    stints = %Stints{
      data: [
        generate_stint(1, 1),
        generate_stint(2, 5),
        generate_stint(3, 10)
      ]
    }

    laps = %Laps{
      data: [
        generate_lap(1, 1000),
        generate_lap(2, 80),
        generate_lap(3, 90),
        generate_lap(4, 1000),
        generate_lap(5, 1000),
        generate_lap(6, 80),
        generate_lap(7, 95),
        generate_lap(8, 95),
        generate_lap(9, 1000),
        generate_lap(10, 1000),
        generate_lap(11, 70),
        generate_lap(12, 90),
        generate_lap(13, 80),
        generate_lap(14, 60)
      ]
    }

    driver_data = %DriverData{
      number: 1,
      stints: stints,
      laps: laps,
      top_speed: 333,
      fastest_lap: Timex.Duration.from_seconds(73)
    }

    expected_summary = %{
      stints: [
        %{
          number: 1,
          lap_start: 1,
          lap_end: 4,
          compound: Enum.at(stints.data, 0) |> Map.fetch!(:compound),
          tyre_age: Enum.at(stints.data, 0) |> Map.fetch!(:age),
          average_time: Timex.Duration.from_seconds(85),
          fastest_time: Timex.Duration.from_seconds(80),
          timed_laps: 2
        },
        %{
          number: 2,
          lap_start: 5,
          lap_end: 9,
          compound: Enum.at(stints.data, 1) |> Map.fetch!(:compound),
          tyre_age: Enum.at(stints.data, 1) |> Map.fetch!(:age),
          average_time: Timex.Duration.from_seconds(90),
          fastest_time: Timex.Duration.from_seconds(80),
          timed_laps: 3
        },
        %{
          number: 3,
          lap_start: 10,
          lap_end: 14,
          compound: Enum.at(stints.data, 2) |> Map.fetch!(:compound),
          tyre_age: Enum.at(stints.data, 2) |> Map.fetch!(:age),
          average_time: Timex.Duration.from_seconds(75),
          fastest_time: Timex.Duration.from_seconds(60),
          timed_laps: 4
        }
      ],
      top_speed: driver_data.top_speed,
      fastest_lap: driver_data.fastest_lap
    }

    actual_summary = Summary.generate(driver_data)

    assert expected_summary == actual_summary
  end
end
