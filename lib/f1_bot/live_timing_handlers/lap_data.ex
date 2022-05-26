defmodule F1Bot.LiveTimingHandlers.LapData do
  @moduledoc """
  Handler for lap times and sector times received from live timing API.

  The handler parses driver information and passes it on to the F1 session instance.
  """
  require Logger
  @behaviour F1Bot.LiveTimingHandlers

  alias F1Bot.LiveTimingHandlers.Event
  @scope "TimingData"

  @impl F1Bot.LiveTimingHandlers
  def process_event(%Event{
        topic: @scope,
        data: %{"Lines" => drivers = %{}},
        timestamp: timestamp
      }) do
    # Lap information is delayed. -3 second offset was chosen because it seems about right, most of the time.
    # Exact timestamps aren't critical at the time of writing this code
    timestamp =
      -3000
      |> Timex.Duration.from_milliseconds()
      |> (&Timex.add(timestamp, &1)).()

    handle_lap_numbers(drivers, timestamp)
    handle_lap_times(drivers, timestamp)
    handle_last_sectors(drivers, timestamp)

    :ok
  end

  defp handle_lap_times(drivers, timestamp) do
    drivers
    |> Enum.filter(fn {_, data} -> data["LastLapTime"]["Value"] not in [nil, ""] end)
    |> Enum.each(fn {driver_number, data} ->
      driver_number = String.trim(driver_number) |> String.to_integer()
      lap_time_str = data["LastLapTime"]["Value"]

      case F1Bot.DataTransform.Parse.parse_lap_time(lap_time_str) do
        {:ok, lap_time} ->
          F1Bot.F1Session.push_lap_time(driver_number, lap_time, timestamp)

        {:error, _error} ->
          Logger.error("Error parsing lap time #{inspect(lap_time_str)}")
      end
    end)
  end

  defp handle_lap_numbers(drivers, timestamp) do
    drivers
    |> Enum.filter(fn {_, data} -> is_integer(data["NumberOfLaps"]) end)
    |> Enum.each(fn {driver_number, data} ->
      driver_number = String.trim(driver_number) |> String.to_integer()
      lap_number = data["NumberOfLaps"]

      F1Bot.F1Session.push_lap_number(driver_number, lap_number, timestamp)
    end)
  end

  defp handle_last_sectors(drivers, timestamp) do
    drivers
    |> Stream.filter(fn {_, data} -> is_map(data["Sectors"]) end)
    |> Stream.filter(fn {_, data} -> is_binary(data["Sectors"]["2"]["Value"]) end)
    |> Stream.each(fn {driver_number, _data} ->
      driver_number = String.trim(driver_number) |> String.to_integer()

      F1Bot.F1Session.push_lap_number(driver_number, nil, timestamp)
    end)
  end
end
