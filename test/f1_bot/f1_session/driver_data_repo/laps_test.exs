defmodule F1Bot.F1Session.DriverDataRepo.LapsTest do
  use ExUnit.Case, async: true

  alias F1Bot.F1Session.DriverDataRepo.{
    Laps,
    Lap
  }

  test "fix_laps_data/1 merges lap number and timings that ended up in separate Lap structs" do
    laps = %Laps{
      data: [
        %Lap{
          number: 8,
          sectors: nil,
          time: nil,
          timestamp: Timex.from_unix(1999)
        },
        %Lap{
          number: nil,
          sectors: %{
            1 => %{
              time: Timex.Duration.from_seconds(25),
              timestamp: Timex.from_unix(1025)
            },
            2 => %{
              time: Timex.Duration.from_seconds(25),
              timestamp: Timex.from_unix(1050)
            },
            3 => %{
              time: Timex.Duration.from_seconds(25),
              timestamp: Timex.from_unix(1075)
            }
          },
          time: Timex.Duration.from_seconds(75),
          timestamp: Timex.from_unix(1075)
        },
        %Lap{
          number: 7,
          sectors: nil,
          time: nil,
          timestamp: Timex.from_unix(999)
        },
        %Lap{
          number: nil,
          sectors: %{
            1 => %{
              time: Timex.Duration.from_seconds(25),
              timestamp: Timex.from_unix(25)
            },
            2 => %{
              time: Timex.Duration.from_seconds(25),
              timestamp: Timex.from_unix(50)
            },
            3 => %{
              time: Timex.Duration.from_seconds(25),
              timestamp: Timex.from_unix(75)
            }
          },
          time: Timex.Duration.from_seconds(75),
          timestamp: Timex.from_unix(75)
        }
      ]
    }

    expected_merged_laps = %Laps{
      data: [
        %Lap{
          number: 8,
          sectors: %{
            1 => %{
              time: Timex.Duration.from_seconds(25),
              timestamp: Timex.from_unix(1025)
            },
            2 => %{
              time: Timex.Duration.from_seconds(25),
              timestamp: Timex.from_unix(1050)
            },
            3 => %{
              time: Timex.Duration.from_seconds(25),
              timestamp: Timex.from_unix(1075)
            }
          },
          time: Timex.Duration.from_seconds(75),
          timestamp: Timex.from_unix(1075)
        },
        %Lap{
          number: 7,
          sectors: %{
            1 => %{
              time: Timex.Duration.from_seconds(25),
              timestamp: Timex.from_unix(25)
            },
            2 => %{
              time: Timex.Duration.from_seconds(25),
              timestamp: Timex.from_unix(50)
            },
            3 => %{
              time: Timex.Duration.from_seconds(25),
              timestamp: Timex.from_unix(75)
            }
          },
          time: Timex.Duration.from_seconds(75),
          timestamp: Timex.from_unix(75)
        }
      ]
    }

    new_laps = Laps.fix_laps_data(laps)

    assert new_laps == expected_merged_laps
  end
end
