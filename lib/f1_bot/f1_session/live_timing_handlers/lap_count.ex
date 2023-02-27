defmodule F1Bot.F1Session.LiveTimingHandlers.LapCount do
  @moduledoc """
  Handler for lap count updates received from live timing API.
  """
  require Logger
  @behaviour F1Bot.F1Session.LiveTimingHandlers

  alias F1Bot.F1Session
  alias F1Bot.F1Session.LiveTimingHandlers.{Packet, ProcessingResult}

  @scope "LapCount"

  @impl F1Bot.F1Session.LiveTimingHandlers
  def process_packet(
        session,
        %Packet{
          topic: @scope,
          data: data,
          timestamp: timestamp
        },
        _options
      ) do
    current = data["CurrentLap"]
    total = data["TotalLaps"]

    current = if is_integer(current), do: current, else: nil
    total = if is_integer(total), do: total, else: nil

    {session, events} = F1Session.push_lap_counter_update(session, current, total, timestamp)

    result = %ProcessingResult{
      session: session,
      events: events
    }

    {:ok, result}
  end
end
