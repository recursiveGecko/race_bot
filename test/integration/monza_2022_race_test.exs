defmodule Integration.Monza2022RaceTest do
  use ExUnit.Case, async: true

  alias F1Bot.F1Session
  alias F1Bot.Replay

  setup_all context do
    replay_options = %Replay.Options{
      exclude_files_regex: ~r/\.z\./
    }

    {:ok, %{session: session}} =
      "https://livetiming.formula1.com/static/2022/2022-09-11_Italian_Grand_Prix/2022-09-11_Race"
      |> Replay.start_replay(replay_options)

    Map.put(context, :session, session)
  end

  test "correctly processes starting tyre compound for #1 Max Verstappen", context do
    stints = stints_for_driver(context.session, 1)

    compounds = stints |> Enum.map(fn s -> s.compound end)
    lap_numbers = stints |> Enum.map(fn s -> s.lap_number end)

    expected_compounds = [:soft, :medium, :soft]
    expected_lap_numbers = [1, 26, 49]

    assert compounds == expected_compounds
    assert lap_numbers == expected_lap_numbers
  end

  test "correctly processes stints for #16 Charles Leclerc", context do
    stints = stints_for_driver(context.session, 16)

    compounds = stints |> Enum.map(fn s -> s.compound end)
    lap_numbers = stints |> Enum.map(fn s -> s.lap_number end)

    expected_compounds = [:soft, :medium, :soft, :soft]
    expected_lap_numbers = [1, 13, 34, 49]

    assert compounds == expected_compounds
    assert lap_numbers == expected_lap_numbers
  end

  defp stints_for_driver(session, driver_number) do
    {:ok, driver_data} = F1Session.driver_session_data(session, driver_number)
    driver_data.stints.data |> order_stints()
  end

  defp order_stints(stints) do
    Enum.sort_by(stints, fn s -> s.number end, :asc)
  end
end
