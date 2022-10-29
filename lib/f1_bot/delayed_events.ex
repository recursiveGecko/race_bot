defmodule F1Bot.DelayedEvents do
  alias F1Bot.DelayedEvents.Rebroadcaster
  alias F1BotWeb.Live

  @min_delay 15_000
  @max_delay 45_000
  @delay_step 1_000
  @available_delays @min_delay..@max_delay//@delay_step

  @min_driver 1
  @max_driver 100

  defdelegate fetch_latest_event(delay_ms, event_scope, event_type),
    to: F1Bot.DelayedEvents.Rebroadcaster

  def available_delays, do: @available_delays
  def min_delay_ms, do: @min_delay
  def max_delay_ms, do: @max_delay
  def delay_step, do: @delay_step

  def subscribe_with_delay!(topic_pairs, delay_ms, send_init_events \\ false) do
    if delay_ms in @available_delays do
      topics =
        Enum.map(topic_pairs, fn {scope, type} ->
          topic_for_event(scope, type, delay_ms)
        end)

      F1Bot.PubSub.subscribe_all(topics)

      if send_init_events do
        send_init_events(topic_pairs, delay_ms, self())
      end

      {:ok, topics}
    else
      {:error, :invalid_delay}
    end
  end

  def topic_for_event(scope, type, delay_ms) do
    base_topic = F1Bot.PubSub.topic_for_event(scope, type)
    "delayed:#{delay_ms}::#{base_topic}"
  end

  def delayed_topic_pairs do
    topics = Live.Telemetry.pubsub_topics()

    per_driver_topics =
      @min_driver..@max_driver
      |> Enum.map(fn driver_no ->
        {:"driver:#{driver_no}", :summary}
      end)

    topics ++ per_driver_topics
  end

  def push_to_all_caches(events) do
    for delay_ms <- @available_delays do
      via = Rebroadcaster.server_via(delay_ms)

      for e <- events do
        send(via, e)
      end
    end
  end

  defp send_init_events(topic_pairs, delay_ms, pid) do
    for {scope, type} <- topic_pairs do
      case fetch_latest_event(delay_ms, scope, type) do
        {:ok, event} -> send(pid, event)
        {:error, :no_data} -> :skip
      end
    end
  end
end
