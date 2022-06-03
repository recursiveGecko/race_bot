defmodule F1Bot.F1Session.LiveTimingHandlers.CarTelemetry do
  @moduledoc """
  Handler for car telemetry received from live timing API.

  The handler decompresses and parses car telemetry channels and passes it on to the F1 session instance.
  """
  require Logger
  @behaviour F1Bot.F1Session.LiveTimingHandlers

  alias F1Bot.F1Session
  alias F1Bot.F1Session.LiveTimingHandlers.Packet
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

  @impl F1Bot.F1Session.LiveTimingHandlers
  def process_packet(session, %Packet{
        topic: @scope,
        data: encoded
      }) do
    case F1Bot.ExternalApi.SignalR.Encoding.decode_live_timing_data(encoded) do
      {:ok, %{"Entries" => batches}} ->
        session = process_decoded_data(session, batches)
        {:ok, session, []}

      {:error, error} ->
        {:error, "Error decoding telemetry data: #{error}"}
    end
  end

  defp process_decoded_data(session, batches) do
    batches
    |> Enum.reduce(session, fn batch, session ->
      %{"Cars" => cars, "Utc" => ts} = batch
      ts = F1Bot.DataTransform.Parse.parse_iso_timestamp(ts)

      reduce_telemetry_per_timestamp(session, cars, ts)
    end)
  end

  defp reduce_telemetry_per_timestamp(session, cars, timestamp) do
    cars
    |> Enum.reduce(session, fn {driver_number, %{"Channels" => channels}}, session ->
      driver_number = String.trim(driver_number) |> String.to_integer()
      channels = parse_telemetry_channels(channels, timestamp)

      F1Session.push_telemetry(session, driver_number, channels)
    end)
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
