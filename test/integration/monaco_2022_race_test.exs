defmodule Integration.Monaco2022RaceTest do
  use ExUnit.Case, async: true

  alias F1Bot.F1Session

  setup_all context do
    replay_options = %{
      exclude_files_regex: ~r/\.z\./
    }

    {:ok, session} =
      "http://livetiming.formula1.com/static/2022/2022-05-29_Monaco_Grand_Prix/2022-05-29_Race"
      |> F1Bot.Replay.session_from_url(replay_options)

    Map.put(context, :session, session)
  end

  test "correctly processes stints for #1 Max Verstappen", context do
    stints = stints_for_driver(context.session, 1)

    compounds = stints |> Enum.map(fn s -> s.compound end)
    lap_numbers = stints |> Enum.map(fn s -> s.lap_number end)

    expected_compounds = [:wet, :intermediate, :hard, :medium]
    expected_lap_numbers = [1, 19, 23, 31]

    assert compounds == expected_compounds
    assert lap_numbers == expected_lap_numbers
  end

  test "correctly processes stints for #16 Charles Leclerc", context do
    stints = stints_for_driver(context.session, 16)

    compounds = stints |> Enum.map(fn s -> s.compound end)
    lap_numbers = stints |> Enum.map(fn s -> s.lap_number end)

    expected_compounds = [:wet, :intermediate, :hard, :hard]
    expected_lap_numbers = [1, 19, 22, 31]

    assert compounds == expected_compounds
    assert lap_numbers == expected_lap_numbers
  end

  test "correctly processes stints for #55 Carlos Sainz", context do
    stints = stints_for_driver(context.session, 55)

    compounds = stints |> Enum.map(fn s -> s.compound end)
    lap_numbers = stints |> Enum.map(fn s -> s.lap_number end)

    expected_compounds = [:wet, :hard, :hard]
    expected_lap_numbers = [1, 22, 31]

    assert compounds == expected_compounds
    assert lap_numbers == expected_lap_numbers
  end

  test "correctly processes stints for #11 Sergio Perez", context do
    stints = stints_for_driver(context.session, 11)

    compounds = stints |> Enum.map(fn s -> s.compound end)
    lap_numbers = stints |> Enum.map(fn s -> s.lap_number end)

    expected_compounds = [:wet, :intermediate, :hard, :medium]
    expected_lap_numbers = [1, 17, 23, 31]

    assert compounds == expected_compounds
    assert lap_numbers == expected_lap_numbers
  end

  test "correctly processes stints for #63 George Russell", context do
    stints = stints_for_driver(context.session, 63)

    compounds = stints |> Enum.map(fn s -> s.compound end)
    lap_numbers = stints |> Enum.map(fn s -> s.lap_number end)

    expected_compounds = [:wet, :hard, :medium]
    expected_lap_numbers = [1, 22, 31]

    assert compounds == expected_compounds
    assert lap_numbers == expected_lap_numbers
  end

  test "correctly processes stints for #18 Lance Stroll", context do
    stints = stints_for_driver(context.session, 18)

    compounds = stints |> Enum.map(fn s -> s.compound end)
    lap_numbers = stints |> Enum.map(fn s -> s.lap_number end)

    expected_compounds = [:wet, :wet, :intermediate, :hard, :hard]
    # Stroll was lapped when the final stint started,
    # making his last stint start on lap 30 instead of 31
    expected_lap_numbers = [1, 2, 3, 25, 30]

    assert compounds == expected_compounds
    assert lap_numbers == expected_lap_numbers
  end

  test "correctly processes stints for #22 Yuki Tsunoda", context do
    stints = stints_for_driver(context.session, 22)

    compounds = stints |> Enum.map(fn s -> s.compound end)
    lap_numbers = stints |> Enum.map(fn s -> s.lap_number end)

    expected_compounds = [:wet, :intermediate, :hard, :medium, :soft]
    # Tsunoda was lapped when the final stint started,
    # making his last stint start on lap 30 instead of 31
    expected_lap_numbers = [1, 7, 22, 30, 57]

    assert compounds == expected_compounds
    assert lap_numbers == expected_lap_numbers
  end

  test "correctly processes stints for #3 Daniel Ricciardo", context do
    stints = stints_for_driver(context.session, 3)

    compounds = stints |> Enum.map(fn s -> s.compound end)
    lap_numbers = stints |> Enum.map(fn s -> s.lap_number end)

    expected_compounds = [:wet, :hard, :hard]
    expected_lap_numbers = [1, 20, 31]

    assert compounds == expected_compounds
    assert lap_numbers == expected_lap_numbers
  end

  test "correctly processes stints for #10 Pierre Gasly", context do
    stints = stints_for_driver(context.session, 10)

    compounds = stints |> Enum.map(fn s -> s.compound end)
    lap_numbers = stints |> Enum.map(fn s -> s.lap_number end)

    # This data is broken beyond repair. Actual compounds should be:
    # [:wet, :intermediate, :hard, :hard], but the packet received during
    # Gasly's lap 13 overwrites stint 0 compound to :intermediate
    # and I couldn't find a way to cross-check or repair it
    actual_expected_compounds = [:wet, :intermediate, :hard, :hard]
    expected_compounds = [:intermediate, :intermediate, :hard, :hard]
    expected_lap_numbers = [1, 3, 23, 31]

    # If this ever triggers it means the error described above has somehow been fixed
    if compounds == actual_expected_compounds do
      flunk("A data integrity error has been fixed ... somehow")
    end

    assert compounds == expected_compounds
    assert lap_numbers == expected_lap_numbers
  end

  test "correctly processes stints for #31 Esteban Ocon", context do
    stints = stints_for_driver(context.session, 31)

    compounds = stints |> Enum.map(fn s -> s.compound end)
    lap_numbers = stints |> Enum.map(fn s -> s.lap_number end)

    expected_compounds = [:wet, :hard, :medium]
    expected_lap_numbers = [1, 22, 31]

    assert compounds == expected_compounds
    assert lap_numbers == expected_lap_numbers
  end

  defp stints_for_driver(session, driver_number) do
    driver_data = F1Session.driver_session_data(session, driver_number)
    driver_data.stints.data |> order_stints()
  end

  defp order_stints(stints) do
    Enum.sort_by(stints, fn s -> s.number end, :asc)
  end
end
