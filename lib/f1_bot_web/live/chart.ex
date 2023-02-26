defmodule F1BotWeb.Live.Chart do
  use F1BotWeb, :live_view
  alias F1BotWeb.Component
  alias F1Bot.DelayedEvents

  data pubsub_delay_ms, :integer, default: DelayedEvents.default_delay()
  data pubsub_delayed_topics, :list, default: []

  def mount(_params, session, socket) do
    delay_ms =
      get_check_param(
        socket,
        "delay_ms",
        socket.assigns.pubsub_delay_ms,
        &DelayedEvents.is_valid_delay?/1
      )

    socket =
      socket
      |> assign(:drivers_of_interest, 1..99)
      |> subscribe_to_own_events(session)
      |> subscribe_with_delay(delay_ms)

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

  @impl true
  def handle_info(
        %{scope: "chart_init:lap_times", payload: chart_class},
        socket
      ) do
    socket = Component.ChartJS.initialize(socket, "lap_times", chart_class)
    {:noreply, socket}
  end

  @impl true
  def handle_info(
        %{scope: "lap_time_chart_data_init:" <> _driver_number, payload: payload},
        socket
      ) do
    socket = Component.ChartJS.replace_data(socket, "lap_times", payload)
    {:noreply, socket}
  end

  @impl true
  def handle_info(
        %{scope: "chart_data_replace:track_status_data", payload: payload},
        socket
      ) do
    socket = Component.ChartJS.replace_data(socket, "lap_times", payload)
    {:noreply, socket}
  end

  defp subscribe_with_delay(socket, delay_ms) do
    existing_topics = socket.assigns[:pubsub_delayed_topics]

    if existing_topics do
      F1Bot.PubSub.unsubscribe_all(existing_topics)
    end

    doi = socket.assigns.drivers_of_interest

    all_subscribed_topics =
      [
        DelayedEvents.subscribe_with_delay(permanent_topics(doi), delay_ms, true),
        DelayedEvents.subscribe_with_delay(permanent_topics_noinit(doi), delay_ms, false)
      ]
      |> Enum.filter(fn {res, _} -> res == :ok end)
      |> Enum.map(fn {_res, topics} -> topics end)
      |> List.flatten()

    DelayedEvents.oneshot_init(oneshot_topics(doi), delay_ms)

    socket
    |> assign(:pubsub_delay_ms, delay_ms)
    |> assign(:pubsub_delayed_topics, all_subscribed_topics)
  end

  defp permanent_topics(driver_numbers) do
    [
      "chart_init:lap_times",
      "chart_data_replace:track_status_data",
      for driver_no <- driver_numbers do
        "lap_time_chart_data_init:#{driver_no}"
      end
    ]
    |> List.flatten()
  end

  defp oneshot_topics(_driver_numbers) do
    [
      # (for driver_no <- driver_numbers do
      #   "lap_time_chart_data_init:#{driver_no}"
      # end)
    ]
    |> List.flatten()
  end

  defp permanent_topics_noinit(_driver_numbers) do
    [
      # for driver_no <- driver_numbers do
      #   "lap_time_chart_data_insert:#{driver_no}"
      # end
    ]
    |> List.flatten()
  end
end
