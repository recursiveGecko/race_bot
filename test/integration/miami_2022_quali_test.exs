defmodule Integration.Miami2022QualiTest do
  use ExUnit.Case, async: true

  alias F1Bot.F1Session
  alias F1Bot.Replay

  setup_all context do
    replay_options = %Replay.Options{
      exclude_files_regex: ~r/\.z\./
    }

    {:ok, %{session: session}} =
      "http://livetiming.formula1.com/static/2022/2022-05-08_Miami_Grand_Prix/2022-05-07_Qualifying"
      |> Replay.start_replay(replay_options)

    Map.put(context, :session, session)
  end

  test "lap fields are correctly merged for #16 Charles Leclerc", context do
    laps = laps_for_driver(context.session, 16)

    # During quali sessions the first lap is always "fake" for some reason,
    # 2nd lap starts as soon as drivers leave the pits for the first time
    laps_without_first = Enum.reject(laps, fn %{number: n} -> n == 1 end)

    laps_with_number_only =
      Enum.filter(laps_without_first, fn l ->
        l.number != nil and l.sectors == nil and l.time == nil
      end)

    assert laps_with_number_only == [], inspect(laps_with_number_only, pretty: true)
  end

  defp laps_for_driver(session, driver_number) do
    {:ok, driver_data} = F1Session.driver_session_data(session, driver_number)
    driver_data.laps.data |> order_laps()
  end

  defp order_laps(laps) do
    Enum.sort_by(laps, fn l -> l.timestamp end, {:asc, DateTime})
  end
end
