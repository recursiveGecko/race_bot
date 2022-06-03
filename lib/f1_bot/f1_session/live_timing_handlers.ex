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

  @doc """
  Called by SignalR client for each received packet.
  """
  def process_live_timing_packet(session = %F1Session{}, packet = %Packet{}) do
    try do
      process_for_topic(session, packet)
    rescue
      e ->
        err_text = Exception.format(:error, e, __STACKTRACE__)
        Logger.error("LiveTimingHandlers rescued an error. Details:\n#{err_text}")
        session
    end
  end

  defp process_for_topic(session, packet = %Packet{topic: "DriverList"}) do
    LiveTimingHandlers.DriverList.process_packet(session, packet)
  end

  defp process_for_topic(session, packet = %Packet{topic: "SessionInfo"}) do
    LiveTimingHandlers.SessionInfo.process_packet(session, packet)
  end

  defp process_for_topic(session, packet = %Packet{topic: "SessionStatus"}) do
    LiveTimingHandlers.SessionStatus.process_packet(session, packet)
  end

  # Ignore initialization messages sent on other topics
  defp process_for_topic(session, _packet = %Packet{init: true}) do
    {:ok, session, []}
  end

  defp process_for_topic(session, packet = %Packet{topic: "CarData"}) do
    LiveTimingHandlers.CarTelemetry.process_packet(session, packet)
  end

  defp process_for_topic(session, packet = %Packet{topic: "Position"}) do
    LiveTimingHandlers.PositionData.process_packet(session, packet)
  end

  defp process_for_topic(session, packet = %Packet{topic: "TimingData"}) do
    LiveTimingHandlers.LapData.process_packet(session, packet)
  end

  defp process_for_topic(session, packet = %Packet{topic: "RaceControlMessages"}) do
    LiveTimingHandlers.RaceControlMessages.process_packet(session, packet)
  end

  defp process_for_topic(session, packet = %Packet{topic: "TimingAppData"}) do
    LiveTimingHandlers.StintData.process_packet(session, packet)
  end

  defp process_for_topic(session, _packet = %Packet{topic: _topic}) do
    # Logger.warn("Received a message for unknown topic: #{topic}")
    {:ok, session, []}
  end
end
