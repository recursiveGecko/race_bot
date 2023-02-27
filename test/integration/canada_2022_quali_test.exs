defmodule Integration.Canada2022QualiTest do
  @moduledoc """
  Live Timing API recorded a lap time of 1:11.324 for Max Verstappen (#1)
  which was 10 seconds faster than anyone else in the session and obviously incorrect.

  The lap is missing a lap number and sector times.
  """
  use ExUnit.Case, async: true
  alias F1Bot.Replay

  setup_all context do
    replay_options = %Replay.Options{
      exclude_files_regex: ~r/\.z\./
    }

    {:ok, %{session: session}} =
      "http://livetiming.formula1.com/static/2022/2022-06-19_Canadian_Grand_Prix/2022-06-18_Qualifying/"
      |> Replay.start_replay(replay_options)

    {:ok, fastest_lap} = "1:21.299" |> F1Bot.DataTransform.Parse.parse_lap_time()

    context
    |> Map.put(:session, session)
    |> Map.put(:actual_fastest_lap, fastest_lap)
  end

  test "disregards incorrect lap times", context do
    [fastest_lap | _rest] =
      context.session
      |> all_laps()
      |> Enum.filter(fn lap -> lap.time != nil end)
      |> Enum.sort_by(fn lap -> Timex.Duration.to_milliseconds(lap.time) end, :asc)

    assert fastest_lap.time == context.actual_fastest_lap
  end

  defp all_laps(session) do
    all_driver_data = session.driver_data_repo.drivers

    for driver_data <- Map.values(all_driver_data),
        lap <- driver_data.laps.data do
      lap
    end
  end
end
