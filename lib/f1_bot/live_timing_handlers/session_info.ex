defmodule F1Bot.LiveTimingHandlers.SessionInfo do
  @moduledoc """
  Handler for session information updates received from live timing API.

  The handler parses session information and passes it on to the F1 session instance.

  See `F1Bot.F1Session.SessionInfo` for more information.
  """
  require Logger
  @behaviour F1Bot.LiveTimingHandlers

  alias F1Bot.LiveTimingHandlers.Event
  @scope "SessionInfo"

  @impl F1Bot.LiveTimingHandlers
  def process_event(%Event{
        topic: @scope,
        data: data
      }) do
    session_info = F1Bot.F1Session.SessionInfo.parse_from_json(data)
    F1Bot.F1Session.push_session_info(session_info)

    :ok
  end
end
