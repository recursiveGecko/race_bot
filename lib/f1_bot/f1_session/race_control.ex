defmodule F1Bot.F1Session.RaceControl do
  @moduledoc """
  Stores and generates events for messages from race control.
  """
  use TypedStruct
  alias F1Bot.F1Session

  typedstruct do
    @typedoc "Race Control messages"

    field(:messages, [F1Session.RaceControl.Message.t()], default: [])
  end

  def new do
    %__MODULE__{}
  end

  def push_messages(
        race_control = %__MODULE__{},
        new_messages
      ) do
    messages = race_control.messages ++ new_messages
    race_control = %{race_control | messages: messages}

    events =
      for m <- new_messages do
        make_race_control_message_event(m)
      end

    {race_control, events}
  end

  defp make_race_control_message_event(payload) do
    F1Bot.F1Session.Common.Event.new("race_control:message", payload)
  end
end
