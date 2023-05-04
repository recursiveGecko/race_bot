defmodule F1Bot.PubSub do
  @moduledoc ""
  require Logger
  alias Phoenix.PubSub
  alias F1Bot.F1Session.Common.Event
  alias F1Bot.DelayedEvents

  def topic_for_event(scope) do
    "event:#{scope}"
  end

  @spec subscribe_to_event(String.t()) :: any()
  def subscribe_to_event(scope) do
    topic = topic_for_event(scope)
    subscribe(topic)
  end

  def subscribe(topic, opts \\ []) do
    Logger.debug("[#{inspect(self())}] Subscribing to topic: #{topic} with opts: #{inspect(opts)}")
    PubSub.subscribe(__MODULE__, topic, opts)
  end

  def subscribe_all(topics) when is_list(topics) do
    Enum.each(topics, &subscribe(&1))
  end

  @spec broadcast_events([Event.t()], boolean()) :: any()
  def broadcast_events(events, rebroadcast_delayed \\ true) do
    for e <- events do
      topic = topic_for_event(e.scope)
      broadcast(topic, e)
    end

    if rebroadcast_delayed do
      DelayedEvents.push_to_all(events)
    end
  end

  def broadcast(topic, message) do
    Logger.debug("Broadcasting event: #{topic}, payload: #{inspect(message, limit: 3)}")
    PubSub.broadcast(__MODULE__, topic, message)
  end

  def unsubscribe(topic) do
    PubSub.unsubscribe(__MODULE__, topic)
  end

  def unsubscribe_all(topics) when is_list(topics) do
    Enum.each(topics, &unsubscribe(&1))
  end
end
