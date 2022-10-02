defmodule F1BotWeb.LiveHelpers do

  def fetch_delayed_event_payload(event_scope, event_type, delay_ms, default_val) do
    case F1Bot.DelayedEvents.fetch_latest_event(delay_ms, event_scope, event_type) do
      {:ok, data} -> data.payload
      {:error, :no_data} -> default_val
    end
  end
end
