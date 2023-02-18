defmodule F1BotWeb.LiveHelpers do
  def fetch_delayed_event_payload(event_scope, event_type, delay_ms, default_val) do
    case F1Bot.DelayedEvents.fetch_latest_event(delay_ms, event_scope, event_type) do
      {:ok, data} -> data.payload
      {:error, :no_data} -> default_val
    end
  end

  def subscribe_to_own_events(socket, session) do
    user_uuid = session["user_uuid"]

    if user_uuid do
      F1Bot.PubSub.subscribe("user_events:#{user_uuid}")
    end

    socket
    |> Phoenix.Component.assign(:user_uuid, user_uuid)
  end

  def broadcast_own_event(_user_uuid = nil, _message), do: :ignore
  def broadcast_own_event(user_uuid, message) do
    F1Bot.PubSub.broadcast("user_events:#{user_uuid}", message)
  end
end
