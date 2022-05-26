defmodule F1Bot.LiveTimingHandlers.PositionData do
  @moduledoc """
  Handler for car position received from live timing API.

  The handler decompresses and parses car position data and passes it on to the F1 session instance.
  """
  require Logger
  @behaviour F1Bot.LiveTimingHandlers

  alias F1Bot.LiveTimingHandlers.Event
  @scope "Position"

  @impl F1Bot.LiveTimingHandlers
  def process_event(%Event{
        topic: @scope,
        data: encoded
      }) do
    case F1Bot.ExternalApi.SignalR.Encoding.decode_live_timing_data(encoded) do
      {:ok, %{"Position" => batches}} ->
        for %{"Entries" => cars, "Timestamp" => ts} <- batches do
          ts = F1Bot.DataTransform.Parse.parse_iso_timestamp(ts)

          for {driver_number, car_pos} <- cars do
            driver_number = String.trim(driver_number) |> String.to_integer()
            parsed = parse_position_data(car_pos, ts)

            # TODO: Batch to avoid passing so many messages between processes
            F1Bot.F1Session.push_position(driver_number, parsed)
          end
        end

        :ok

      {:error, error} ->
        {:error, "Error decoding telemetry data: #{error}"}
    end
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
