defmodule F1Bot.F1Session.LiveTimingHandlers.LapData do
  @moduledoc """
  Handler for lap times and sector times received from live timing API.

  The handler parses driver information and passes it on to the F1 session instance.
  """
  require Logger
  @behaviour F1Bot.F1Session.LiveTimingHandlers

  alias F1Bot.F1Session
  alias F1Bot.F1Session.LiveTimingHandlers.{Packet, ProcessingResult}
  alias F1Bot.DataTransform.Parse

  @scope "TimingData"

  @impl F1Bot.F1Session.LiveTimingHandlers
  def process_packet(
        session,
        %Packet{
          topic: @scope,
          data: %{"Lines" => drivers = %{}},
          timestamp: timestamp
        },
        _options
      ) do
    # Lap information is delayed. -2.5 second offset was chosen because it seems about right, most of the time.
    # Exact timestamps aren't critical at the time of writing this code
    timestamp =
      -2500
      |> Timex.Duration.from_milliseconds()
      |> (&Timex.add(timestamp, &1)).()

    {session, lap_num_events} = handle_lap_numbers(session, drivers, timestamp)
    {session, lap_time_events} = handle_lap_times(session, drivers, timestamp)
    {session, sector_time_events} = handle_sector_times(session, drivers, timestamp)

    all_events = sector_time_events ++ lap_num_events ++ lap_time_events

    result = %ProcessingResult{
      session: session,
      events: all_events
    }

    {:ok, result}
  end

  @impl F1Bot.F1Session.LiveTimingHandlers
  def process_packet(_session, _invalid_packet, _options) do
    {:error, :invalid_packet}
  end

  defp handle_lap_times(session, drivers, timestamp) do
    drivers
    |> Enum.filter(fn {_, data} -> data["LastLapTime"]["Value"] not in [nil, ""] end)
    |> Enum.reduce({session, []}, fn {driver_number, data}, {session, events} ->
      driver_number = String.trim(driver_number) |> String.to_integer()
      lap_time_str = data["LastLapTime"]["Value"]

      case Parse.parse_lap_time(lap_time_str) do
        {:ok, lap_time} ->
          {session, new_events} =
            F1Session.push_lap_time(session, driver_number, lap_time, timestamp)

          {session, events ++ new_events}

        {:error, _error} ->
          Logger.error("Error parsing lap time #{inspect(lap_time_str)}")
          {session, events}
      end
    end)
  end

  defp handle_lap_numbers(session, drivers, timestamp) do
    {session, events} =
      drivers
      |> Enum.filter(fn {_, data} -> is_integer(data["NumberOfLaps"]) end)
      |> Enum.reduce({session, []}, fn {driver_number, data}, {session, events} ->
        driver_number = String.trim(driver_number) |> String.to_integer()
        lap_number = data["NumberOfLaps"]

        {new_session, new_events} =
          F1Session.push_lap_number(session, driver_number, lap_number, timestamp)

        {new_session, events ++ new_events}
      end)

    {session, events}
  end

  defp handle_sector_times(session, drivers, timestamp) do
    {session, nested_events} =
      drivers
      |> Stream.filter(fn {_, data} -> is_map(data["Sectors"]) end)
      |> Enum.reduce({session, []}, &reduce_sector_times_per_driver(&1, &2, timestamp))

    events = List.flatten(nested_events)
    {session, events}
  end

  defp reduce_sector_times_per_driver({driver_number, data}, {session, events}, timestamp) do
    %{"Sectors" => sectors = %{}} = data
    driver_number = String.trim(driver_number) |> String.to_integer()

    ["0", "1", "2"]
    |> Enum.reduce({session, events}, fn sector_str, {session, events} ->
      sector_time_str = sectors[sector_str]["Value"]
      sector = String.to_integer(sector_str) + 1

      with true <- is_binary(sector_time_str),
           true <- sector_time_str != "",
           {:ok, sector_time} <- Parse.parse_lap_time(sector_time_str) do
        {session, new_events} =
          F1Session.push_sector_time(session, driver_number, sector, sector_time, timestamp)

        {session, events ++ new_events}
      else
        {:error, _error} ->
          Logger.error("Error parsing sector time #{inspect(sector_time_str)}")
          {session, events}

        _ ->
          {session, events}
      end
    end)
  end
end
