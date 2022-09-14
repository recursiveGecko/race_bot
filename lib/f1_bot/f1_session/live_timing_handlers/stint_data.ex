defmodule F1Bot.F1Session.LiveTimingHandlers.StintData do
  @moduledoc """
  Handler for stint information (tyre changes) received from live timing API.

  The handler parses the stint data and passes it on to the F1 session instance.
  """
  require Logger
  @behaviour F1Bot.F1Session.LiveTimingHandlers

  alias F1Bot.F1Session
  alias F1Bot.F1Session.LiveTimingHandlers.Packet
  @scope "TimingAppData"

  @impl F1Bot.F1Session.LiveTimingHandlers
  def process_packet(session, %Packet{
        topic: @scope,
        data: %{"Lines" => drivers = %{}},
        timestamp: timestamp
      }) do
    {session, events} =
      drivers
      |> Enum.filter(fn {_, data} ->
        stints = data["Stints"]
        is_map(stints) or is_list(stints)
      end)
      |> Enum.map(fn {driver_no, data} ->
        stints = data["Stints"]

        # Normalize list-based stints to map-based stints,
        # usually seen in first message of a session
        stints =
          if is_list(stints) do
            for {stint, index} <- Enum.with_index(stints), into: %{} do
              {"#{index}", stint}
            end
          else
            stints
          end

        data = Map.put(data, "Stints", stints)
        {driver_no, data}
      end)
      |> Enum.reduce({session, []}, &reduce_stints_per_driver(&1, &2, timestamp))

    {:ok, session, events}
  end

  defp reduce_stints_per_driver({driver_number, data}, {session, events}, timestamp) do
    %{"Stints" => stints} = data
    driver_number = String.trim(driver_number) |> String.to_integer()

    stints
    |> Enum.reduce({session, events}, fn {stint_number_str, raw_stint_data}, {session, events} ->
      stint_number = String.to_integer(stint_number_str)
      start_laps = raw_stint_data["StartLaps"]
      total_laps = raw_stint_data["TotalLaps"]
      raw_tyres_not_changed = raw_stint_data["TyresNotChanged"]
      raw_new = raw_stint_data["New"]
      raw_compound = raw_stint_data["Compound"]

      valid_compounds = ["WET", "INTERMEDIATE", "HARD", "MEDIUM", "SOFT"]

      compound =
        if raw_compound in valid_compounds do
          raw_compound |> String.downcase() |> String.to_atom()
        else
          nil
        end

      age =
        cond do
          start_laps != nil ->
            start_laps

          # Only encountered "true" in real data but I'm covering all my bases
          raw_new in ["true", "True", "TRUE", true, 1] ->
            0

          true ->
            nil
        end

      stint_data = %{
        number: stint_number,
        compound: compound,
        age: age,
        total_laps: total_laps,
        timestamp: timestamp,
        tyres_changed:
          case raw_tyres_not_changed do
            nil -> nil
            val -> val == "0"
          end
      }

      {session, new_events} = F1Session.push_stint_data(session, driver_number, stint_data)
      {session, events ++ new_events}
    end)
  end
end
