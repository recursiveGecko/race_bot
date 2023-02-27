defmodule F1Bot.F1Session.LiveTimingHandlers.SessionInfo do
  @moduledoc """
  Handler for session information updates received from live timing API.

  The handler parses session information and passes it on to the F1 session instance.

  See `F1Bot.F1Session.SessionInfo` for more information.
  """
  require Logger
  alias F1Bot.F1Session.LiveTimingHandlers

  alias F1Bot.F1Session
  alias LiveTimingHandlers.{Packet, ProcessingResult}

  @behaviour LiveTimingHandlers
  @scope "SessionInfo"

  @impl F1Bot.F1Session.LiveTimingHandlers
  def process_packet(
        session,
        %Packet{
          topic: @scope,
          data: data
        },
        options
      ) do
    session_info = F1Bot.F1Session.SessionInfo.parse_from_json(data)
    {session, events, reset_session} = F1Session.push_session_info(session, session_info, options.ignore_reset)

    result = %ProcessingResult{
      session: session,
      events: events,
      reset_session: reset_session
    }

    {:ok, result}
  end
end
