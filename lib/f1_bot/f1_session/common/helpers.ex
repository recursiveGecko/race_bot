defmodule F1Bot.F1Session.Common.Helpers do
  @moduledoc """
  Helpers for publishing events that trigger side-effects.
  """
  alias F1Bot.F1Session.Common.Event

  @spec publish_events([Event.t()]) :: any()
  def publish_events(events) do
    for e <- events do
      topic = topic_for_event(e.scope, e.type)
      F1Bot.PubSub.broadcast(topic, e)
    end
  end

  @spec subscribe_to_event(String.t() | atom(), String.t() | atom()) :: any()
  def subscribe_to_event(scope, type) do
    topic = topic_for_event(scope, type)
    F1Bot.PubSub.subscribe(topic)
  end

  def topic_for_event(scope, type) do
    "state_machine:#{scope}:#{type}"
  end
end
