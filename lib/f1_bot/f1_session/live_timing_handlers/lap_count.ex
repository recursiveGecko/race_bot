defmodule F1Bot.F1Session.LiveTimingHandlers.LapCount do
  @moduledoc """
  Handler for lap count updates received from live timing API.
  """
  require Logger
  @behaviour F1Bot.F1Session.LiveTimingHandlers

  alias F1Bot.F1Session
  alias F1Bot.F1Session.LapCounter
  alias F1Bot.F1Session.LiveTimingHandlers.Packet
  @scope "LapCount"

  @impl F1Bot.F1Session.LiveTimingHandlers
  def process_packet(session, %Packet{
        topic: @scope,
        data: data
      }) do
    current = data["CurrentLap"]
    total = data["TotalLaps"]

    current = if is_integer(current), do: current, else: nil
    total = if is_integer(total), do: total, else: nil

    partial_lap_counter = LapCounter.new(current, total)

    {session, events} = F1Session.push_session_lap_counter(session, partial_lap_counter)
    {:ok, session, events}
  end
end
