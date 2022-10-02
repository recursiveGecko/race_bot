defmodule F1BotWeb.Live.Telemetry do
  use F1BotWeb, :live_view
  alias F1BotWeb.Component
  alias F1Bot.DataTransform.Format

  data session_clock, :any, default: nil
  data session_info, :any, default: nil
  data driver_list, :list
  data drivers_of_interest, :list, default: [1, 11, 16, 55]

  def mount(_params, _session, socket) do
    initial_delay = 25_000

    socket =
      socket
      |> Surface.init()
      |> init_assigns()
      |> subscribe_with_delay(initial_delay)

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle-driver", params, socket) do
    driver_no = String.to_integer(params["driver-number"])
    is_doi = driver_no in socket.assigns.drivers_of_interest

    drivers_of_interest =
      if is_doi do
        Enum.reject(socket.assigns.drivers_of_interest, &(&1 == driver_no))
      else
        [driver_no | socket.assigns.drivers_of_interest]
      end

    socket =
      socket
      |> assign(:drivers_of_interest, drivers_of_interest)
      |> subscribe_with_delay()

    {:noreply, socket}
  end

  @impl true
  def handle_event("delay-inc", _params, socket) do
    step_ms = F1Bot.DelayedEvents.delay_step()
    delay_ms = socket.assigns.pubsub_delay_ms + step_ms
    socket = subscribe_with_delay(socket, delay_ms)

    {:noreply, socket}
  end

  @impl true
  def handle_event("delay-dec", _params, socket) do
    step_ms = F1Bot.DelayedEvents.delay_step()
    delay_ms = socket.assigns.pubsub_delay_ms - step_ms
    socket = subscribe_with_delay(socket, delay_ms)

    {:noreply, socket}
  end

  @impl true
  def handle_info(e = %{type: :summary}, socket) do
    Component.DriverSummary.handle_summary_event(e)
    {:noreply, socket}
  end

  @impl true
  def handle_info(
        %{scope: :driver, type: :list, payload: driver_list},
        socket
      ) do
    socket = assign(socket, driver_list: driver_list)
    {:noreply, socket}
  end

  @impl true
  def handle_info(
        %{scope: :session_info, type: :session_clock, payload: session_clock},
        socket
      ) do
    socket = assign(socket, session_clock: session_clock)
    {:noreply, socket}
  end

  @impl true
  def handle_info(
        %{scope: :session_info, type: :session_info_changed, payload: session_info},
        socket
      ) do
    socket = assign(socket, session_info: session_info)
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

    global_topics = [
      {:driver, :list},
      {:session_info, :session_info_changed},
      {:session_info, :session_clock}
    ]

    per_driver_topics = per_driver_topic_pairs(socket.assigns.drivers_of_interest)

    topics_to_subscribe = global_topics ++ per_driver_topics

    {:ok, subscribed_topics} =
      F1Bot.DelayedEvents.subscribe_with_delay!(
        topics_to_subscribe,
        delay_ms,
        true
      )

    socket
    |> assign(:pubsub_delay_ms, delay_ms)
    |> assign(:pubsub_delayed_topics, subscribed_topics)
  end

  defp per_driver_topic_pairs(driver_numbers) do
    driver_numbers
    |> Enum.map(fn driver_no ->
      {:"driver:#{driver_no}", :summary}
    end)
  end

  defp init_assigns(socket) do
    keys = [driver_list: [], session_clock: nil, session_info: nil]

    Enum.reduce(keys, socket, fn {k, v}, s ->
      assign_new(s, k, fn -> v end)
    end)
  end

  defp min_delay_ms(), do: F1Bot.DelayedEvents.min_delay_ms()
  defp max_delay_ms(), do: F1Bot.DelayedEvents.max_delay_ms()

  defp is_race?(_session_info = nil), do: false
  defp is_race?(session_info), do: F1Bot.F1Session.SessionInfo.is_race?(session_info)
end
