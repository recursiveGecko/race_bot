defmodule F1Bot.PubSub do
  @moduledoc ""
  alias Phoenix.PubSub

  def subscribe(topic, opts \\ []) do
    PubSub.subscribe(F1Bot.PubSub, topic, opts)
  end

  def subscribe_all(topics) when is_list(topics) do
    Enum.each(topics, &subscribe(&1))
  end

  def broadcast(topic, message) do
    PubSub.broadcast(F1Bot.PubSub, topic, message)
  end

  def unsubscribe(topic) do
    PubSub.unsubscribe(F1Bot.PubSub, topic)
  end

  def unsubscribe_all(topics) when is_list(topics) do
    Enum.each(topics, &unsubscribe(&1))
  end

  defdelegate topic_for_event(scope, type), to: F1Bot.F1Session.Common.Helpers
end
