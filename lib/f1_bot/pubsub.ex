defmodule F1Bot.PubSub do
  @moduledoc ""
  alias Phoenix.PubSub

  def subscribe(topic, opts \\ []) do
    PubSub.subscribe(:f1_pubsub, topic, opts)
  end

  def broadcast(topic, message) do
    PubSub.broadcast(:f1_pubsub, topic, message)
  end
end
