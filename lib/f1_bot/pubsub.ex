defmodule F1Bot.PubSub do
  @moduledoc ""
  alias Phoenix.PubSub

  def subscribe(topic, opts \\ []) do
    PubSub.subscribe(F1Bot.PubSub, topic, opts)
  end

  def broadcast(topic, message) do
    PubSub.broadcast(F1Bot.PubSub, topic, message)
  end
end
