defmodule F1BotWeb.Live.Chart do
  use F1BotWeb, :live_view
  alias F1BotWeb.Component

  data pubsub_delay_ms, :integer, default: 1_000
  data pubsub_delayed_topics, :list, default: []

  def mount(_params, session, socket) do
    socket =
      socket
      |> subscribe_to_own_events(session)
      |> subscribe_with_delay()

    {:ok, socket}
  end

  @impl true
  def handle_info(
        {:delay_control_set, delay_ms},
        socket
      ) do
    # Broadcast event for all LiveViews to synchronize delay across tabs/windows
    broadcast_own_event(socket.assigns.user_uuid, {:user_set_delay_ms, delay_ms})
    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {:user_set_delay_ms, delay_ms},
        socket
      ) do
    # Handle broadcasted delay control event to synchronize all tabs/windows
    socket = subscribe_with_delay(socket, delay_ms)
    {:noreply, socket}
  end

  defp subscribe_with_delay(socket, delay_ms \\ nil) do
    delay_ms =
      if delay_ms == nil do
        socket.assigns.pubsub_delay_ms
      else
        delay_ms
      end

    existing_topics = socket.assigns[:pubsub_delayed_topics]

    if existing_topics do
      F1Bot.PubSub.unsubscribe_all(existing_topics)
    end

    all_subscribed_topics = []

    socket
    |> assign(:pubsub_delay_ms, delay_ms)
    |> assign(:pubsub_delayed_topics, all_subscribed_topics)
  end
end
