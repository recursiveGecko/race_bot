defmodule F1Bot.F1Session.LiveTimingHandlers.PositionData do
  @moduledoc """
  Handler for car position received from live timing API.

  The handler decompresses and parses car position data and passes it on to the F1 session instance.
  """
  require Logger
  @behaviour F1Bot.F1Session.LiveTimingHandlers

  alias F1Bot.F1Session
  alias F1Bot.F1Session.LiveTimingHandlers.Packet
  @scope "Position"

  @impl F1Bot.F1Session.LiveTimingHandlers
  def process_packet(session, %Packet{
        topic: @scope,
        data: encoded
      }) do
    case F1Bot.ExternalApi.SignalR.Encoding.decode_live_timing_data(encoded) do
      {:ok, %{"Position" => batches}} ->
        session = process_decoded_data(session, batches)
        {:ok, session, []}

      {:error, error} ->
        {:error, "Error decoding telemetry data: #{error}"}
    end
  end

  defp process_decoded_data(session, batches) do
    batches
    |> Enum.reduce(session, fn batch, session ->
      %{"Entries" => cars, "Timestamp" => ts} = batch
      ts = F1Bot.DataTransform.Parse.parse_iso_timestamp(ts)

      reduce_positions_per_timestamp(session, cars, ts)
    end)
  end

  defp reduce_positions_per_timestamp(session, cars, timestamp) do
    cars
    |> Enum.reduce(session, fn {driver_number, car_pos}, session ->
      driver_number = String.trim(driver_number) |> String.to_integer()
      parsed = parse_position_data(car_pos, timestamp)

      F1Session.push_position(session, driver_number, parsed)
    end)
  end

  defp parse_position_data(car_pos, timestamp) do
    %{
      x: Map.fetch!(car_pos, "X"),
      y: Map.fetch!(car_pos, "Y"),
      z: Map.fetch!(car_pos, "Z"),
      status: Map.fetch!(car_pos, "Status"),
      timestamp: timestamp
    }
  end
end
