defmodule F1Bot.F1Session.LiveTimingHandlers.TrackStatus do
  @moduledoc """
  Handler for track status received from live timing API.

  The handler parses the status as an atom and passes it on to the F1 session instance.
  """
  require Logger
  @behaviour F1Bot.F1Session.LiveTimingHandlers

  alias F1Bot.F1Session
  alias F1Bot.F1Session.LiveTimingHandlers.{Packet, ProcessingResult}

  @scope "TrackStatus"

  @status_map %{
    1 => :all_clear,
    2 => :yellow_flag,
    4 => :safety_car,
    5 => :red_flag,
    6 => :virtual_safety_car
  }

  @impl F1Bot.F1Session.LiveTimingHandlers
  def process_packet(
        session,
        %Packet{
          topic: @scope,
          data: %{"Status" => status_str},
          timestamp: timestamp
        },
        _options
      ) do
    status_int = String.to_integer(status_str)
    status = Map.get(@status_map, status_int)

    {session, events} =
      if status == nil do
        {session, []}
      else
        F1Session.push_track_status(session, status, timestamp)
      end

    result = %ProcessingResult{
      session: session,
      events: events
    }

    {:ok, result}
  end
end
