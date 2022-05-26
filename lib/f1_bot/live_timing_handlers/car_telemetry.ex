defmodule F1Bot.LiveTimingHandlers.CarTelemetry do
  @moduledoc """
  Handler for car telemetry received from live timing API.

  The handler decompresses and parses car telemetry channels and passes it on to the F1 session instance.
  """
  require Logger
  @behaviour F1Bot.LiveTimingHandlers

  alias F1Bot.LiveTimingHandlers.Event
  @scope "CarData"

  # {'0': 'RPM', '2': 'Speed', '3': 'nGear', '4': 'Throttle', '5': 'Brake', '45': 'DRS'}
  @channels %{
    "0" => :rpm,
    "2" => :speed,
    "3" => :gear,
    "4" => :throttle,
    "5" => :brake,
    "45" => :drs
  }

  @drs_values %{
    0 => :off,
    8 => :available,
    10 => :on,
    12 => :on,
    14 => :on
  }

  @impl F1Bot.LiveTimingHandlers
  def process_event(%Event{
        topic: @scope,
        data: encoded
      }) do
    case F1Bot.ExternalApi.SignalR.Encoding.decode_live_timing_data(encoded) do
      {:ok, %{"Entries" => batches}} ->
        for %{"Cars" => cars, "Utc" => ts} <- batches do
          ts = F1Bot.DataTransform.Parse.parse_iso_timestamp(ts)

          for {driver_number, %{"Channels" => channels}} <- cars do
            driver_number = String.trim(driver_number) |> String.to_integer()
            channels = parse_telemetry_channels(channels, ts)

            # TODO: Batch to avoid passing so many messages between processes
            F1Bot.F1Session.push_telemetry(driver_number, channels)
          end
        end

        :ok

      {:error, error} ->
        {:error, "Error decoding telemetry data: #{error}"}
    end
  end

  defp parse_telemetry_channels(channels, timestamp) do
    parsed =
      @channels
      |> Enum.map(fn {source, target} -> {target, channels[source]} end)
      |> Enum.into(%{})

    drs = Map.get(@drs_values, parsed.drs, :off)

    %{parsed | drs: drs}
    |> Map.put(:timestamp, timestamp)
  end
end
