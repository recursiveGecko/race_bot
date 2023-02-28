defmodule Integration.Saudi2022QualiTest do
  use ExUnit.Case, async: true

  alias F1Bot.F1Session
  alias F1Bot.Replay

  setup_all context do
    replay_options = %Replay.Options{
      exclude_files_regex: ~r/\.z\./
    }

    {:ok, %{session: session}} =
      "https://livetiming.formula1.com/static/2022/2022-03-27_Saudi_Arabian_Grand_Prix/2022-03-26_Qualifying"
      |> Replay.start_replay(replay_options)

    Map.put(context, :session, session)
  end

  test "correctly processes stints for #11 Sergio Perez", context do
    stints = stints_for_driver(context.session, 11)

    compounds = stints |> Enum.map(fn s -> s.compound end)
    lap_numbers = stints |> Enum.map(fn s -> s.lap_number end)

    expected_compounds = [:soft, :soft, :soft, :soft, :soft, :soft]
    expected_lap_numbers = [2, 4, 9, 12, 15, 18]

    assert compounds == expected_compounds
    assert lap_numbers == expected_lap_numbers
  end

  test "correctly processes lap times for #11 Sergio Perez", context do
    lap_times = lap_times_for_driver(context.session, 11, 100)

    expected_lap_times =
      [
        "1:30.111",
        # "2:27.094",
        "1:29.705",
        "1:28.924",
        "1:32.296",
        "1:28.554",
        "1:28.200"
      ]
      |> parse_lap_times()

    assert lap_times == expected_lap_times
  end

  defp stints_for_driver(session, driver_number) do
    {:ok, driver_data} = F1Session.driver_session_data(session, driver_number)
    driver_data.stints.data |> order_stints()
  end

  defp lap_times_for_driver(session, driver_number, max_time_sec) do
    max_time = Timex.Duration.from_seconds(max_time_sec)

    {:ok, driver_data} = F1Session.driver_session_data(session, driver_number)

    driver_data.laps.data
    |> Enum.filter(fn l -> l.time != nil end)
    |> Enum.filter(fn l -> Timex.Duration.diff(l.time, max_time, :milliseconds) < 0 end)
    |> Enum.sort_by(fn l -> l.number end, :asc)
    |> Enum.map(fn l -> l.time end)
  end

  defp parse_lap_times(lap_times) do
    lap_times
    |> Enum.map(fn l ->
      {:ok, lap_time} = F1Bot.DataTransform.Parse.parse_lap_time(l)
      lap_time
    end)
  end

  defp order_stints(stints) do
    Enum.sort_by(stints, fn s -> s.number end, :asc)
  end
end
