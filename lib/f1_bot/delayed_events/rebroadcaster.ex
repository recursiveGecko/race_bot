defmodule F1Bot.DelayedEvents.Rebroadcaster do
  use GenServer
  alias F1Bot.DelayedEvents
  alias F1Bot.Ets

  @ets_table_prefix "delayed_events"

  def start_link(options) do
    delay_ms = Keyword.fetch!(options, :delay_ms)

    options = %{
      delay_ms: delay_ms
    }

    GenServer.start_link(__MODULE__, options, name: server_via(delay_ms))
  end

  def server_via(delay_ms) do
    :"#{__MODULE__}::#{delay_ms}"
  end

  def fetch_latest_event(delay_ms, event_scope) do
    if delay_ms in DelayedEvents.available_delays() do
      delay_ms
      |> ets_table_name()
      |> Ets.fetch(to_string(event_scope))
    else
      {:error, :invalid_delay}
    end
  end

  def clear_cache(delay_ms) do
    delay_ms
    |> server_via()
    |> GenServer.call(:clear_cache)
  end

  @impl true
  def init(options) do
    {:ok, timer_ref} = :timer.send_interval(100, :rebroadcast)

    options.delay_ms
    |> ets_table_name()
    |> Ets.new()

    state =
      options
      |> Map.put(:events, [])
      |> Map.put(:timer_ref, timer_ref)

    {:ok, state}
  end

  @impl true
  def handle_call(:clear_cache, _from, state) do
    state = %{state | events: []}

    state.delay_ms
    |> ets_table_name()
    |> Ets.clear()

    flush_mailbox()

    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:rebroadcast, state) do
    delay_ms = state.delay_ms
    now = System.monotonic_time(:millisecond)

    until_ts = now - delay_ms
    state = rebroadcast_batch(state, until_ts)

    {:noreply, state}
  end

  @impl true
  def handle_info({:events, events}, state) do
    # TODO: Ensure that events are re-sorted by timestamp

    # Events should be sorted by timestamp,
    # no further sorting is performed here because
    # other parts of the system (currently) generate events
    # with the current timestamp, which gives them natural order
    state = update_in(state.events, &(&1 ++ events))

    {:noreply, state}
  end

  defp rebroadcast_batch(%{events: []} = state, _until_ts), do: state

  defp rebroadcast_batch(%{events: [event | rest_events]} = state, until_ts) do
    # Assumes that events are approximately sorted by timestamp
    if event.timestamp <= until_ts do
      save_latest_event(state, event)
      do_rebroadcast(state, event)

      state = %{state | events: rest_events}

      rebroadcast_batch(state, until_ts)
    else
      state
    end
  end

  defp do_rebroadcast(state, event) do
    topic = DelayedEvents.delayed_topic_for_event(event.scope, state.delay_ms)
    F1Bot.PubSub.broadcast(topic, event)
  end

  defp save_latest_event(state, event) do
    state.delay_ms
    |> ets_table_name()
    |> Ets.insert(to_string(event.scope), event)
  end

  defp flush_mailbox() do
    receive do
      _ -> flush_mailbox()
    after
      0 -> :ok
    end
  end

  defp ets_table_name(delay_ms), do: :"#{@ets_table_prefix}_#{delay_ms}"
end
