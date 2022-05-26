defmodule F1Bot.F1Session.Common.Helpers do
  @moduledoc """
  Helpers for publishing events that trigger side-effects.
  """
  alias F1Bot.F1Session.Common.Event

  @spec publish_events([Event.t()]) :: any()
  def publish_events(events) do
    for e <- events do
      F1Bot.PubSub.broadcast("state_machine:#{e.scope}:#{e.type}", e)
    end
  end

  @spec subscribe_to_event(String.t() | atom(), String.t() | atom()) :: any()
  def subscribe_to_event(scope, type) do
    F1Bot.PubSub.subscribe("state_machine:#{scope}:#{type}")
  end
end
