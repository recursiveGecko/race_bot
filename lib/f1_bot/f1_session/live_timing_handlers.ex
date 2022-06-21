defmodule F1Bot.F1Session.LiveTimingHandlers do
  @moduledoc """
  Router for all packets ingested from F1 SignalR websocket API
  """
  require Logger
  alias F1Bot.F1Session
  alias F1Bot.F1Session.Common.Event
  alias F1Bot.F1Session.LiveTimingHandlers
  alias F1Bot.F1Session.LiveTimingHandlers.Packet

  @callback process_packet(F1Session.t(), Packet.t()) ::
              {:ok, F1Session.t(), [Event.t()]} | {:error, any()}

  @session_inactive_statuses [nil, :finalised, :ends]

  @doc """
  Called by SignalR client for each received packet.
  """
  def process_live_timing_packet(session = %F1Session{}, packet = %Packet{}, options) do
    try do
      process_for_topic(session, packet, options)
    rescue
      e ->
        err_text = Exception.format(:error, e, __STACKTRACE__)
        Logger.error("LiveTimingHandlers rescued an error. Details:\n#{err_text}")
        session
    end
  end

  defp process_for_topic(session, packet = %Packet{topic: "DriverList"}, _options) do
    LiveTimingHandlers.DriverList.process_packet(session, packet)
  end

  defp process_for_topic(session, packet = %Packet{topic: "SessionInfo"}, _options) do
    LiveTimingHandlers.SessionInfo.process_packet(session, packet)
  end

  defp process_for_topic(session, packet = %Packet{topic: "SessionStatus"}, _options) do
    LiveTimingHandlers.SessionStatus.process_packet(session, packet)
  end

  # Ignore initialization messages sent on other topics
  defp process_for_topic(session, _packet = %Packet{init: true}, _options) do
    {:ok, session, []}
  end

  # TODO: Implement time-synchronization
  defp process_for_topic(session, _packet = %Packet{topic: "Heartbeat"}, _options) do
    {:ok, session, []}
  end

  # Ignore all other packets when session is inactive
  defp process_for_topic(session, packet = %Packet{}, options)
       when session.session_status in @session_inactive_statuses do
    log = Map.get(options, :log_stray_packets, true)

    if log do
      Logger.info(
        "Ignored received packet while session is inactive: #{inspect(packet, pretty: true)}"
      )
    end

    {:ok, session, []}
  end

  defp process_for_topic(session, packet = %Packet{topic: "CarData"}, _options) do
    LiveTimingHandlers.CarTelemetry.process_packet(session, packet)
  end

  defp process_for_topic(session, packet = %Packet{topic: "Position"}, _options) do
    LiveTimingHandlers.PositionData.process_packet(session, packet)
  end

  defp process_for_topic(session, packet = %Packet{topic: "TimingData"}, _options) do
    LiveTimingHandlers.LapData.process_packet(session, packet)
  end

  defp process_for_topic(session, packet = %Packet{topic: "RaceControlMessages"}, _options) do
    LiveTimingHandlers.RaceControlMessages.process_packet(session, packet)
  end

  defp process_for_topic(session, packet = %Packet{topic: "TimingAppData"}, _options) do
    LiveTimingHandlers.StintData.process_packet(session, packet)
  end

  defp process_for_topic(session, packet = %Packet{topic: "TrackStatus"}, _options) do
    LiveTimingHandlers.TrackStatus.process_packet(session, packet)
  end

  defp process_for_topic(session, _packet = %Packet{topic: _topic}, __options) do
    # Logger.warn("Received a message for unknown topic: #{topic}")
    {:ok, session, []}
  end
end
