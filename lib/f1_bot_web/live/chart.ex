defmodule F1BotWeb.Live.Chart do
  use F1BotWeb, :live_view
  alias F1BotWeb.Component

  alias F1Bot.DelayedEvents

  data pubsub_delay_ms, :integer, default: 1_000
  data pubsub_delayed_topics, :list, default: []

  def mount(_params, session, socket) do
    socket =
      socket
      |> assign(:drivers_of_interest, 1..99)
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

  @impl true
  def handle_info(
        %{scope: :chart_init, type: :lap_times, payload: chart_init},
        socket
      ) do
    socket = Component.VegaChart.initialize(socket, "lap_times", chart_init.spec)
    {:noreply, socket}
  end

  @impl true
  def handle_info(
        %{scope: :lap_time_chart_data_init, type: _driver_number, payload: lt_data},
        socket
      ) do
    socket = Component.VegaChart.replace_data(socket, "lap_times", lt_data.dataset, lt_data.data)
    {:noreply, socket}
  end

  @impl true
  def handle_info(
        %{scope: :chart_data_replace, type: :track_status_data, payload: ts_data},
        socket
      ) do
    socket = Component.VegaChart.replace_data(socket, "lap_times", ts_data.dataset, ts_data.data)
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

    doi = socket.assigns.drivers_of_interest

    all_subscribed_topics =
      [
        DelayedEvents.subscribe_with_delay(permanent_topics(), delay_ms, true),
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

  defp permanent_topics do
    [
      {:chart_init, :lap_times},
      {:chart_data_replace, :track_status_data}
    ]
  end

  defp oneshot_topics(driver_numbers) do
    [
      (for driver_no <- driver_numbers do
        {:lap_time_chart_data_init, :"#{driver_no}"}
      end)
    ]
    |> List.flatten()
  end

  defp permanent_topics_noinit(driver_numbers) do
    [
      (for driver_no <- driver_numbers do
        {:lap_time_chart_data_insert, :"#{driver_no}"}
      end)
    ]
    |> List.flatten()
  end
end
