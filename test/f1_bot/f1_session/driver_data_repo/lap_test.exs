defmodule F1Bot.F1Session.DriverDataRepo.LapTest do
  use ExUnit.Case, async: true

  alias F1Bot.F1Session.TrackStatusHistory
  alias F1Bot.F1Session.DriverDataRepo.Lap

  def ts(unix_seconds), do: Timex.from_unix(unix_seconds, :second)
  def duration(seconds), do: Timex.Duration.from_seconds(seconds)

  test "is_neutralized?/2 - without neutralization periods" do
    lap = %Lap{
      number: 0,
      sectors: nil,
      time: duration(100),
      timestamp: ts(1100)
    }

    neutralization_periods = []

    assert Lap.is_neutralized?(lap, neutralization_periods) == false
  end

  test "is_neutralized?/2 - neutralization periods finishing before the lap begins" do
    lap = %Lap{
      number: 0,
      sectors: nil,
      time: duration(100),
      timestamp: ts(1100)
    }

    neutralization_periods = [
      TrackStatusHistory.new_interval(:yellow_flag, ts(0), ts(100)),
      TrackStatusHistory.new_interval(:safety_car, ts(400), ts(900))
    ]

    assert Lap.is_neutralized?(lap, neutralization_periods) == false
  end

  test "is_neutralized?/2 - neutralization periods starting after the lap is completed" do
    lap = %Lap{
      number: 0,
      sectors: nil,
      time: duration(100),
      timestamp: ts(1100)
    }

    neutralization_periods = [
      TrackStatusHistory.new_interval(:yellow_flag, ts(1101), ts(1200)),
      TrackStatusHistory.new_interval(:safety_car, ts(1500), ts(1800))
    ]

    assert Lap.is_neutralized?(lap, neutralization_periods) == false
  end

  test "is_neutralized?/2 - neutralization period starting before lap begins and ending after lap is completed" do
    lap = %Lap{
      number: 0,
      sectors: nil,
      time: duration(100),
      timestamp: ts(1100)
    }

    neutralization_periods = [
      TrackStatusHistory.new_interval(:safety_car, ts(900), ts(1200))
    ]

    assert Lap.is_neutralized?(lap, neutralization_periods) == true
  end

  test "is_neutralized?/2 - neutralization period starting and ending during the lap" do
    lap = %Lap{
      number: 0,
      sectors: nil,
      time: duration(100),
      timestamp: ts(1100)
    }

    neutralization_periods = [
      TrackStatusHistory.new_interval(:yellow_flag, ts(1050), ts(1060))
    ]

    assert Lap.is_neutralized?(lap, neutralization_periods) == true
  end

  test "is_neutralized?/2 - neutralization period starting before lap begins and ending during the lap" do
    lap = %Lap{
      number: 0,
      sectors: nil,
      time: duration(100),
      timestamp: ts(1100)
    }

    neutralization_periods = [
      TrackStatusHistory.new_interval(:virtual_safety_car, ts(900), ts(1050))
    ]

    assert Lap.is_neutralized?(lap, neutralization_periods) == true
  end

  test "is_neutralized?/2 - neutralization period starting during the lap and ending after lap is completed" do
    lap = %Lap{
      number: 0,
      sectors: nil,
      time: duration(100),
      timestamp: ts(1100)
    }

    neutralization_periods = [
      TrackStatusHistory.new_interval(:virtual_safety_car, ts(1050), ts(1200))
    ]

    assert Lap.is_neutralized?(lap, neutralization_periods) == true
  end

  test "is_neutralized?/2 - unfinished neutralization period starting before the lap begins" do
    lap = %Lap{
      number: 0,
      sectors: nil,
      time: duration(100),
      timestamp: ts(1100)
    }

    neutralization_periods = [
      TrackStatusHistory.new_interval(:safety_car, ts(900), nil)
    ]

    assert Lap.is_neutralized?(lap, neutralization_periods) == true
  end

  test "is_neutralized?/2 - unfinished neutralization period starting during the lap" do
    lap = %Lap{
      number: 0,
      sectors: nil,
      time: duration(100),
      timestamp: ts(1100)
    }

    neutralization_periods = [
      TrackStatusHistory.new_interval(:safety_car, ts(1050), nil)
    ]

    assert Lap.is_neutralized?(lap, neutralization_periods) == true
  end

  test "is_neutralized?/2 - unfinished neutralization period starting after the lap is completed" do
    lap = %Lap{
      number: 0,
      sectors: nil,
      time: duration(100),
      timestamp: ts(1100)
    }

    neutralization_periods = [
      TrackStatusHistory.new_interval(:safety_car, ts(1200), nil)
    ]

    assert Lap.is_neutralized?(lap, neutralization_periods) == false
  end
end
