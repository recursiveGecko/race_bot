defmodule F1BotWeb.LiveHelpers do
  alias Phoenix.LiveView

  def fetch_delayed_event_payload(event_scope, delay_ms, default_val) do
    case F1Bot.DelayedEvents.fetch_latest_event(delay_ms, event_scope) do
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

  def get_check_param(socket, param_name, default_val, check_fn)
      when is_binary(param_name) and is_function(check_fn, 1) do
    sent_val = LiveView.get_connect_params(socket)[param_name]

    if sent_val != nil and check_fn.(sent_val) do
      sent_val
    else
      default_val
    end
  end
end
