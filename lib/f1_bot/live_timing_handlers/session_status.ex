defmodule F1Bot.LiveTimingHandlers.SessionStatus do
  @moduledoc """
  Handler for session status received from live timing API.

  The handler parses the status as an atom and passes it on to the F1 session instance.
  """
  require Logger
  @behaviour F1Bot.LiveTimingHandlers

  alias F1Bot.LiveTimingHandlers.Event
  @scope "SessionStatus"

  @impl F1Bot.LiveTimingHandlers
  def process_event(%Event{
        topic: @scope,
        data: %{"Status" => status}
      }) do
    status =
      status
      |> String.trim()
      |> String.downcase()
      |> String.to_atom()

    F1Bot.F1Session.push_session_status(status)
    :ok
  end
end
