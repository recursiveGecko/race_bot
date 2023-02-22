defmodule F1Bot.DelayedEvents do
  alias F1Bot.DelayedEvents.Rebroadcaster

  @min_delay 1_000
  @max_delay 45_000
  @delay_step 1_000
  @available_delays @min_delay..@max_delay//@delay_step

  defdelegate fetch_latest_event(delay_ms, event_scope, event_type),
    to: F1Bot.DelayedEvents.Rebroadcaster

  def available_delays, do: @available_delays
  def min_delay_ms, do: @min_delay
  def max_delay_ms, do: @max_delay
  def delay_step, do: @delay_step

  def subscribe_with_delay(topic_pairs, delay_ms, send_init_events) do
    if delay_ms in @available_delays do
      topics =
        Enum.map(topic_pairs, fn {scope, type} ->
          delayed_topic_for_event(scope, type, delay_ms)
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

  @doc """
  Send the latest event for each topic pair for topics that follow the
  init + delta pattern, e.g. charts where the init event contains the bulky
  chart specification and later events only contain new data points to add.
  """
  def oneshot_init(topic_pairs, delay_ms) do
    if delay_ms in @available_delays do
      send_init_events(topic_pairs, delay_ms, self())
      :ok
    else
      {:error, :invalid_delay}
    end
  end

  def delayed_topic_for_event(scope, type, delay_ms) do
    base_topic = F1Bot.PubSub.topic_for_event(scope, type)
    "delayed:#{delay_ms}::#{base_topic}"
  end

  def push_to_all(events) do
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
